import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:idara_esign/core/constants/storage_keys.dart';
import 'package:idara_esign/core/networking/networking.dart';
import 'package:idara_esign/core/security/secure_storage.dart';
import 'package:idara_esign/di/injection_container.dart';
import 'package:idara_esign/features/auth/presentation/bloc/auth_bloc.dart';

class AuthInterceptor extends QueuedInterceptor {
  final SecureStorage _secureStorage;
  final Dio _dio;
  final Dio _refreshDio;

  /// Once set to true, all subsequent 401s are rejected immediately
  /// without attempting refresh. Prevents cascading refresh+logout cycles.
  bool _forceLogout = false;

  AuthInterceptor({
    required SecureStorage secureStorage,
    required Dio dio,
    required Dio refreshDio,
  }) : _secureStorage = secureStorage,
       _dio = dio,
       _refreshDio = refreshDio;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      if (_requiresToken(options)) {
        final token = await _secureStorage.read(key: StorageKeys.authToken);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      }
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
        debugPrint('🚫 AuthInterceptor: Logout already triggered, rejecting.');
        handler.reject(err);
        return;
      }

      try {
        debugPrint(
          '🔄 AuthInterceptor: 401 received. Attempting to refresh token...',
        );

        final newToken = await _attemptTokenRefresh();

        if (newToken != null) {
          debugPrint('✅ AuthInterceptor: Token refreshed successfully!');

          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer $newToken';
          options.extra['_isRetryAfterRefresh'] = true;

          final response = await _dio.fetch(options);
          handler.resolve(response);
        } else {
          debugPrint('❌ AuthInterceptor: Token refresh returned empty token.');
          _triggerLogout();
          handler.reject(err);
        }
      } on DioException catch (e) {
        debugPrint('❌ AuthInterceptor: Token refresh failed: ${e.message}');
        _triggerLogout();
        handler.reject(e);
      } catch (e) {
        debugPrint('❌ AuthInterceptor: Token refresh error: $e');
        _triggerLogout();
        handler.reject(err);
      }
    } else {
      handler.next(err);
    }
  }

  Future<String?> _attemptTokenRefresh() async {
    final currentToken = await _secureStorage.read(key: StorageKeys.authToken);

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
      await _secureStorage.write(key: StorageKeys.authToken, value: newToken);
      return newToken;
    }
    return null;
  }

  bool _requiresToken(RequestOptions options) {
    final path = options.path;
    return !path.contains(ApiConstant.login);
  }

  bool _shouldAttemptRefreshOn401(RequestOptions options) {
    if (options.extra['_isRetryAfterRefresh'] == true) return false;

    final path = options.path;
    if (path.contains(ApiConstant.login) ||
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
      _secureStorage.deleteAll();
      getIt<AuthBloc>().add(const LogoutEvent());
    } catch (e) {
      debugPrint('Failed to trigger logout from interceptor: $e');
    }
  }
}
