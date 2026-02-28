import 'package:idara_esign/core/networking/error/app_failure.dart';

sealed class AppException implements Exception {
  final String message;
  final String? prefix;
  final int? code;
  final Map<String, dynamic>? data;

  const AppException(this.message, {this.prefix, this.code, this.data});

  @override
  String toString() =>
      '${prefix ?? 'AppException'}: $message (Code: ${code ?? 'N/A'}) ${data != null ? 'Data: $data' : ''}';
}
class ServerException extends AppException {
  const ServerException([
    super.message = "Server error occurred.",
    String prefix = "Server",
    int? code,
    Map<String, dynamic>? data,
  ]) : super(prefix: prefix, code: code, data: data);
}

class NoInternetException extends AppException {
  const NoInternetException([
    super.message = "No Internet connection. Please check your network.",
    String prefix = "Network",
    int? code,
    Map<String, dynamic>? data,
  ]) : super(prefix: prefix, code: code, data: data);
}

class RequestTimeoutException extends AppException {
  const RequestTimeoutException([
    super.message =
        'Oops! Something took too long to load. Please check your internet and try again.',
    String prefix = "Timeout",
    int? code,
    Map<String, dynamic>? data,
  ]) : super(prefix: prefix, code: code, data: data);
}

class CacheException extends AppException {
  const CacheException([
    super.message = "Cache error occurred.",
    String prefix = "Cache",
    int? code,
    Map<String, dynamic>? data,
  ]) : super(prefix: prefix, code: code, data: data);
}

class BadRequestException extends AppException {
  const BadRequestException([
    super.message = "Invalid request.",
    String prefix = "Bad Request",
    int? code,
    Map<String, dynamic>? data,
  ]) : super(prefix: prefix, code: code, data: data);
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([
    super.message = "Unauthorized access.",
    String prefix = "Auth",
    int? code,
    Map<String, dynamic>? data,
  ]) : super(prefix: prefix, code: code, data: data);
}

class AccessForbiddenException extends AppException {
  const AccessForbiddenException([
    super.message = "Access forbidden.",
    String prefix = "Access Forbidden",
    int? code,
    Map<String, dynamic>? data,
  ]) : super(prefix: prefix, code: code, data: data);
}

class InvalidInputException extends AppException {
  const InvalidInputException([
    super.message = "Invalid input provided.",
    String prefix = "Input Error",
    int? code,
    Map<String, dynamic>? data,
  ]) : super(prefix: prefix, code: code, data: data);
}

class FetchDataException extends AppException {
  const FetchDataException([
    super.message = "Unable to fetch data.",
    String prefix = "Fetch Error",
    int? code,
    Map<String, dynamic>? data,
  ]) : super(prefix: prefix, code: code, data: data);
}

class CustomException extends AppException {
  const CustomException(
    super.message, {
    String super.prefix = "Custom Status",
    super.code,
    super.data,
  });
}

class NotFoundException extends AppException {
  const NotFoundException([
    super.message = "Resource not found.",
    String prefix = "Not Found",
    int? code,
    Map<String, dynamic>? data,
  ]) : super(prefix: prefix, code: code, data: data);
}

class UnknownException extends AppException {
  const UnknownException([
    super.message = "An unknown error occurred.",
    String prefix = "Unknown",
    int? code,
    Map<String, dynamic>? data,
  ]) : super(prefix: prefix, code: code, data: data);
}

extension AppExceptionToFailure on AppException {
  AppFailure toFailure() => switch (this) {
    NoInternetException _ ||
    RequestTimeoutException _ => NetworkFailure(message, code, data),
    CacheException _ => CacheFailure(message, code, data),
    BadRequestException _ ||
    UnauthorizedException _ ||
    InvalidInputException _ ||
    FetchDataException _ ||
    NotFoundException _ ||
    CustomException _ => ServerFailure(message, code, data),
    _ => UnknownFailure(message, code, data),
  };
}
