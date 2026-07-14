import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:idara_esign/core/networking/auth_token_store.dart';

/// A self-contained, app-agnostic Dio auth interceptor.
///
/// Responsibilities:
/// - Attaches the Bearer token to every request except [_publicPaths].
/// - On an auth failure ([_refreshStatusCodes], default 401) refreshes the
///   token once and retries the failed request. Concurrent 401s share a
///   single refresh call, and requests whose token was already refreshed by
///   a previous request are retried without refreshing again.
/// - When refresh fails, fires [_onForceLogout] exactly once and rejects all
///   further auth failures until a public (login-like) request resets state.
///
/// Everything app-specific is injected, so this file can be copied between
/// projects unchanged — only the [AuthTokenStore] interface must exist.
///
/// ```dart
/// AuthInterceptor(
///   tokenStore: tokenStore,
///   dio: dio,
///   refreshDio: refreshDio, // separate Dio WITHOUT this interceptor
///   refreshPath: ApiConstant.refreshToken,
///   publicPaths: [ApiConstant.login, ApiConstant.register],
///   skipRefreshPaths: [ApiConstant.revokeAllTokens],
///   localeProvider: () => prefs.getString(StorageKeys.locale) ?? 'en',
///   onForceLogout: () => getIt<AuthBloc>().add(const LogoutEvent()),
/// )
/// ```
class AuthInterceptor extends QueuedInterceptor {
  final AuthTokenStore _tokenStore;
  final Dio _dio;
  final Dio _refreshDio;

  /// Endpoint the refresh request is posted to (via [_refreshDio]).
  final String _refreshPath;

  /// Endpoints that never carry a Bearer token. A request to one of these
  /// also resets the interceptor state for the next session.
  final List<String> _publicPaths;

  /// Endpoints that carry a token but where an auth failure means the
  /// session is already dead — refreshing would restart the logout cycle.
  /// Always includes [_refreshPath] as defense against wiring mistakes.
  final List<String> _skipRefreshPaths;

  /// Status codes treated as "token expired, try a refresh". Only add 403
  /// if the backend returns it for expired tokens — otherwise a genuine
  /// permission error would force-logout the user.
  final Set<int> _refreshStatusCodes;

  /// Extracts the new token from the refresh response body.
  final String? Function(Object? responseData) _tokenExtractor;

  /// Returns the Accept-Language value, or null to skip the header.
  final String? Function()? _localeProvider;

  /// Called when refresh fails and the session must be terminated.
  /// Wire this to the app's logout flow (bloc event, navigator, etc).
  final void Function()? _onForceLogout;

  /// Once set to true, all subsequent auth failures are rejected immediately
  /// without attempting refresh. Prevents cascading refresh+logout cycles.
  bool _forceLogout = false;
  Completer<String?>? _refreshCompleter;

  static const String _retryFlagKey = '_isRetryAfterRefresh';

  AuthInterceptor({
    required AuthTokenStore tokenStore,
    required Dio dio,
    required Dio refreshDio,
    required String refreshPath,
    required List<String> publicPaths,
    List<String> skipRefreshPaths = const [],
    Set<int> refreshStatusCodes = const {401},
    String? Function(Object? responseData)? tokenExtractor,
    String? Function()? localeProvider,
    void Function()? onForceLogout,
  }) : _tokenStore = tokenStore,
       _dio = dio,
       _refreshDio = refreshDio,
       _refreshPath = refreshPath,
       _publicPaths = publicPaths,
       _skipRefreshPaths = [refreshPath, ...skipRefreshPaths],
       _refreshStatusCodes = refreshStatusCodes,
       _tokenExtractor = tokenExtractor ?? _defaultTokenExtractor,
       _localeProvider = localeProvider,
       _onForceLogout = onForceLogout;

  /// Default response shape: `{ "data": { "token": "..." } }`.
  static String? _defaultTokenExtractor(Object? responseData) {
    final data = responseData as Map<String, dynamic>?;
    return (data?['data'] as Map<String, dynamic>?)?['token']?.toString();
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      if (_requiresToken(options)) {
        final token = await _tokenStore.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      } else {
        debugPrint(
          'AuthInterceptor: Public auth request detected. Auto-resetting state.',
        );
        _resetState();
      }

      final locale = _localeProvider?.call();
      if (locale != null) {
        options.headers['Accept-Language'] = locale;
      }
    } catch (e) {
      debugPrint('AuthInterceptor: Failed to attach auth token: $e');
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_refreshStatusCodes.contains(err.response?.statusCode) &&
        _shouldAttemptRefresh(err.requestOptions)) {
      // If logout was already triggered, skip refresh entirely
      if (_forceLogout) {
        debugPrint('AuthInterceptor: Logout already triggered, rejecting.');
        return handler.reject(err);
      }

      try {
        final String? failedRequestToken =
            (err.requestOptions.headers['Authorization'] as String?)
                ?.replaceAll('Bearer ', '');
        final String? currentTokenInStorage = await _tokenStore.getToken();

        if (failedRequestToken != null &&
            currentTokenInStorage != null &&
            failedRequestToken != currentTokenInStorage) {
          debugPrint(
            'AuthInterceptor: Token already refreshed by previous request. Retrying...',
          );

          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer $currentTokenInStorage';

          final response = await _dio.fetch(options);
          return handler.resolve(response);
        }

        debugPrint(
          'AuthInterceptor: ${err.response?.statusCode} received With body: ${err.response?.data}. Attempting to refresh token...',
        );
        final newToken = await _attemptTokenRefresh();

        if (newToken != null) {
          debugPrint('AuthInterceptor: Token refreshed successfully!');

          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer $newToken';
          options.extra[_retryFlagKey] = true;

          final response = await _dio.fetch(options);
          return handler.resolve(response);
        } else {
          debugPrint('AuthInterceptor: Token refresh returned empty token.');
          _triggerLogout();
          return handler.reject(err);
        }
      } on DioException catch (e) {
        debugPrint('AuthInterceptor: Token refresh failed: ${e.message}');
        _triggerLogout();
        return handler.reject(e);
      } catch (e) {
        debugPrint('AuthInterceptor: Token refresh error: $e');
        _triggerLogout();
        return handler.reject(err);
      }
    } else {
      return handler.next(err);
    }
  }

  Future<String?> _attemptTokenRefresh() async {
    if (_refreshCompleter != null) {
      debugPrint('AuthInterceptor: Waiting for existing refresh Completer...');
      return await _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();
    // The initiating request receives failures via `rethrow`, so when no
    // concurrent request is awaiting this future, completeError would raise
    // an unhandled async error ("RethrownDartError" on web). ignore() adds a
    // no-op error listener; actual waiters still get the error normally.
    _refreshCompleter!.future.ignore();

    try {
      final newToken = await _doRefreshToken();

      _refreshCompleter!.complete(newToken);

      return newToken;
    } catch (e) {
      _refreshCompleter!.completeError(e);
      rethrow;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<String?> _doRefreshToken() async {
    final currentToken = await _tokenStore.getToken();

    final response = await _refreshDio.post(
      _refreshPath,
      options: Options(
        headers: {
          if (currentToken != null) 'Authorization': 'Bearer $currentToken',
        },
      ),
    );

    final newToken = _tokenExtractor(response.data);

    if (newToken != null && newToken.isNotEmpty) {
      final isPersistent = await _tokenStore.isPersistentSession();
      await _tokenStore.saveToken(newToken, persist: isPersistent);
      return newToken;
    }
    return null;
  }

  bool _requiresToken(RequestOptions options) =>
      !_publicPaths.any(options.path.contains);

  bool _shouldAttemptRefresh(RequestOptions options) {
    if (options.extra[_retryFlagKey] == true) return false;
    if (!_requiresToken(options)) return false;
    if (_skipRefreshPaths.any(options.path.contains)) return false;

    return true;
  }

  void _triggerLogout() {
    if (_forceLogout) return; // Already triggered, don't fire logout again
    _forceLogout = true;

    try {
      debugPrint('🔌 AuthInterceptor: Triggering forced logout');
      _onForceLogout?.call();
    } catch (e) {
      debugPrint('AuthInterceptor: Failed to trigger logout: $e');
    }
  }

  /// to reset the interceptor state for the next session.
  void _resetState() {
    _forceLogout = false;
    _refreshCompleter = null;
    debugPrint('AuthInterceptor: State reset successfully.');
  }
}
