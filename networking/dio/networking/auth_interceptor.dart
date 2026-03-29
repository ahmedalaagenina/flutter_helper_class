import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:idara_esign/core/constants/storage_keys.dart';
import 'package:idara_esign/core/networking/networking.dart';
import 'package:idara_esign/di/injection_container.dart';
import 'package:idara_esign/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthInterceptor extends QueuedInterceptor {
  final SharedPreferences _prefs;
  final AuthTokenStore _tokenStore;
  final Dio _dio;
  final Dio _refreshDio;

  /// Once set to true, all subsequent 401s are rejected immediately
  /// without attempting refresh. Prevents cascading refresh+logout cycles.
  bool _forceLogout = false;
  Completer<String?>? _refreshCompleter;

  AuthInterceptor({
    required SharedPreferences prefs,
    required AuthTokenStore tokenStore,
    required Dio dio,
    required Dio refreshDio,
  }) : _prefs = prefs,
       _tokenStore = tokenStore,
       _dio = dio,
       _refreshDio = refreshDio;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_requiresToken(options)) {
      debugPrint(
        'AuthInterceptor: Login/Register request detected. Auto-resetting state.',
      );
      _resetState();
    }
    try {
      if (_requiresToken(options)) {
        final token = await _tokenStore.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      }
      options.headers['Accept-Language'] =
          _prefs.getString(StorageKeys.locale) ?? 'en';
    } catch (e) {
      debugPrint('Failed to attach auth token: $e');
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 &&
        _shouldAttemptRefreshOn401(err.requestOptions)) {
      // If logout was already triggered, skip refresh entirely
      if (_forceLogout) {
        debugPrint('AuthInterceptor: Logout already triggered, rejecting.');
        return handler.reject(err);
      }

      try {
        final String? failedRequestToken = err
            .requestOptions
            .headers['Authorization']
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
          'AuthInterceptor: 401 received. Attempting to refresh token...',
        );
        final newToken = await _attemptTokenRefresh();

        if (newToken != null) {
          debugPrint('AuthInterceptor: Token refreshed successfully!');

          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer $newToken';
          options.extra['_isRetryAfterRefresh'] = true;

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
      ApiConstant.refreshToken,
      options: Options(
        headers: {
          if (currentToken != null) 'Authorization': 'Bearer $currentToken',
        },
      ),
    );

    final data = response.data;
    final newToken = data?['data']?['token']?.toString();

    if (newToken != null && newToken.isNotEmpty) {
      final isPersistent = await _tokenStore.isPersistentSession();
      await _tokenStore.saveToken(newToken, persist: isPersistent);
      return newToken;
    }
    return null;
  }

  bool _requiresToken(RequestOptions options) {
    final path = options.path;
    return !(path.contains(ApiConstant.login) ||
        path.contains(ApiConstant.register));
  }

  bool _shouldAttemptRefreshOn401(RequestOptions options) {
    if (options.extra['_isRetryAfterRefresh'] == true) return false;

    final path = options.path;
    if (path.contains(ApiConstant.login) ||
        path.contains(ApiConstant.register) ||
        path.contains(ApiConstant.revokeAllTokens) ||
        path.contains('logout') ||
        path.contains('revoke')) {
      return false;
    }
    return true;
  }

  void _triggerLogout() {
    if (_forceLogout) return; // Already triggered, don't fire LogoutEvent again
    _forceLogout = true;

    try {
      debugPrint('🔌 AuthInterceptor: Triggering forced logout');
      getIt<AuthBloc>().add(const LogoutEvent());
    } catch (e) {
      debugPrint('Failed to trigger logout from interceptor: $e');
    }
  }

  /// to reset the interceptor state for the next session.
  void _resetState() {
    _forceLogout = false;
    _refreshCompleter = null;
    debugPrint('AuthInterceptor: State resetted successfully.');
  }
}
