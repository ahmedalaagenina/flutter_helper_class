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
    // We only care about 401 Unauthorized errors from non-auth endpoints
    if (err.response?.statusCode == 401 &&
        _shouldAttemptRefreshOn401(err.requestOptions)) {
      try {
        debugPrint(
          '🔄 AuthInterceptor: 401 received. Attempting to refresh token...',
        );

        final newToken = await _attemptTokenRefresh();

        if (newToken != null) {
          debugPrint('✅ AuthInterceptor: Token refreshed successfully!');

          // Update the Authorization header and retry the original request
          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer $newToken';
          // Mark as retried so we don't refresh again if this also gets 401
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
      // Not a 401 or it's an auth request 401 (e.g., login failed with wrong password)
      handler.next(err);
    }
  }


  /// Refreshes the auth token using [_refreshDio] (no interceptors).
  /// Returns the new token on success, or throws on failure.
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
    try {
      debugPrint('🔌 AuthInterceptor: Triggering forced logout');
      getIt<AuthBloc>().add(const LogoutEvent());
    } catch (e) {
      debugPrint('Failed to trigger logout from interceptor: $e');
    }
  }
}
