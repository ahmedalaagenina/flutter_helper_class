import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:idara_esign/core/networking/networking.dart';
import 'package:idara_esign/core/services/logger_service.dart';
import 'package:idara_esign/generated/l10n.dart';

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
        return const CustomException("Request was cancelled.");
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const RequestTimeoutException();
      case DioExceptionType.badResponse:
        return _mapStatusCodeToException(statusCode, message);
      case DioExceptionType.badCertificate:
        return const CustomException("Bad certificate received from server.");
      case DioExceptionType.connectionError:
        return const NoInternetException();
      case DioExceptionType.unknown:
        return UnknownException(error.message ?? "Unexpected Dio error.");
      default:
        return UnknownException(S.current.unexpectedError);
    }
  }

  /// Maps HTTP status codes to proper AppExceptions.
  static AppException _mapStatusCodeToException(int code, String message) {
    switch (code) {
      case 400:
        return BadRequestException(
          "${S.current.badRequestCheckInput} $message",
        );
      case 401:
        return UnauthorizedException(
          "${S.current.unauthorizedPleaseLogin} $message",
        );
      case 403:
        return UnauthorizedException("${S.current.accessForbidden} $message");
      case 404:
        return NotFoundException("${S.current.resourceNotFound} $message");
      case 422:
        return InvalidInputException(message);
      case 500:
        return ServerException("${S.current.serverErrorTryLater} $message");
      case 503:
        return ServerException(
          "${S.current.serviceUnavailableTryLater} $message",
        );
      default:
        return FetchDataException("${S.current.genericErrorTryAgain} $code");
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

    return "Something went wrong.";
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
