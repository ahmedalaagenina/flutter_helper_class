import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:idara_driver/core/networking/networking.dart';
import 'package:idara_driver/generated/l10n.dart';
import 'package:idara_driver/core/util/app_log.dart';

class ApiFailureHandler {
  ApiFailureHandler._();

  /// Entry point to handle and convert any thrown error to a [Failure].
  static AppFailure handle(dynamic error) {
    final AppException exception = _mapErrorToAppException(error);
    _logError(error, exception);
    return exception.toFailure();
  }

  /// Maps all types of errors (Dio, Socket, Timeout, etc.) to an [AppException].
  static AppException _mapErrorToAppException(dynamic error) {
    switch (error) {
      case DioException():
        return _mapDioException(error);
      case SocketException() when !kIsWeb:
        return const NoInternetException();
      case TimeoutException():
        return const RequestTimeoutException();
      case CacheException():
        return const CacheException();
      case FormatException():
        return const CustomException("Invalid data format received.");
      default:
        return const UnknownException("An unknown error occurred.");
    }
  }

  /// Handles Dio-specific errors with detailed inspection.
  static AppException _mapDioException(DioException error) {
    final int statusCode = error.response?.statusCode ?? 0;
    final dynamic data = error.response?.data;
    final String message = _extractMessage(data);
    switch (error.type) {
      case DioExceptionType.cancel:
        return CustomException(S.current.requestCancelled);
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const RequestTimeoutException();
      case DioExceptionType.badResponse:
        return _mapStatusCodeToException(statusCode, message);
      case DioExceptionType.badCertificate:
        return CustomException(S.current.badCertificate);
      case DioExceptionType.connectionError:
        return NoInternetException(S.current.noInternetConnection);
      case DioExceptionType.unknown:
        return UnknownException(error.message ?? S.current.unexpectedDioError);
    }
  }

  /// Maps HTTP status codes to proper AppExceptions.
  static AppException _mapStatusCodeToException(int code, String message) {
    final hasServerMessage =
        message.isNotEmpty && message != S.current.somethingWentWrong;

    switch (code) {
      case 400:
        return BadRequestException(
          hasServerMessage ? message : S.current.badRequestCheckInput,
        );
      case 401:
        return UnauthorizedException(
          hasServerMessage ? message : S.current.unauthorizedPleaseLogin,
        );
      case 403:
        return UnauthorizedException(
          hasServerMessage ? message : S.current.accessForbidden,
        );
      case 404:
        return NotFoundException(
          hasServerMessage ? message : S.current.resourceNotFound,
        );
      case 422:
        return InvalidInputException(
          hasServerMessage ? message : S.current.badRequestCheckInput,
        );
      case 500:
        return ServerException(
          hasServerMessage ? message : S.current.serverErrorTryLater,
        );
      case 503:
        return ServerException(
          hasServerMessage ? message : S.current.serviceUnavailableTryLater,
        );
      default:
        return FetchDataException(
          hasServerMessage
              ? message
              : "${S.current.genericErrorTryAgain} ($code)",
        );
    }
  }

  /// Extracts human-readable message from a server response.
  static String _extractMessage(dynamic data) {
    try {
      if (data is Map<String, dynamic>) {
        if (data.containsKey('errors')) {
          final errors = data['errors'];
          if (errors is Map) {
            for (final value in errors.values) {
              if (value is List && value.isNotEmpty) {
                final firstMessage = value.first?.toString() ?? '';
                if (firstMessage.isNotEmpty) {
                  return firstMessage;
                }
              }
            }
          }
        }

        if (data.containsKey('message') && data['message'] != null) {
          final message = data['message'].toString();
          if (message.isNotEmpty) return message;
        }

        if (data.containsKey('error')) {
          final error = data['error'];

          if (error is String && error.isNotEmpty) {
            return error;
          }

          if (error is Map && error.containsKey('message')) {
            final msg = error['message']?.toString() ?? '';
            if (msg.isNotEmpty) return msg;
          }
        }
      }
    } catch (_) {}

    return S.current.somethingWentWrong;
  }

  /// Logs the original and mapped error types.
  static void _logError(dynamic original, AppException mapped) {
    AppLog.w("[ApiFailureHandler] Original error: $original");
    AppLog.e(
      "[ApiFailureHandler] Mapped to: ${mapped.runtimeType} — ${mapped.message}",
      mapped.runtimeType,
    );
  }
}
