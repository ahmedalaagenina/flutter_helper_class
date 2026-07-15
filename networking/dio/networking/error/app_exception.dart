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
  const ServerException({
    String message = 'Server error occurred.',
    super.prefix = 'Server',
    super.code,
    super.data,
  }) : super(message);
}

class NoInternetException extends AppException {
  const NoInternetException({
    String message = 'No Internet connection. Please check your network.',
    super.prefix = 'Network',
    super.code,
    super.data,
  }) : super(message);
}

class RequestTimeoutException extends AppException {
  const RequestTimeoutException({
    String message =
        'Oops! Something took too long to load. Please check your internet and try again.',
    super.prefix = 'Timeout',
    super.code,
    super.data,
  }) : super(message);
}

class CacheException extends AppException {
  const CacheException({
    String message = 'Cache error occurred.',
    super.prefix = 'Cache',
    super.code,
    super.data,
  }) : super(message);
}

class BadRequestException extends AppException {
  const BadRequestException({
    String message = 'Invalid request.',
    super.prefix = 'Bad Request',
    super.code,
    super.data,
  }) : super(message);
}

class UnauthorizedException extends AppException {
  const UnauthorizedException({
    String message = 'Unauthorized access.',
    super.prefix = 'Auth',
    super.code,
    super.data,
  }) : super(message);
}

class AccessForbiddenException extends AppException {
  const AccessForbiddenException({
    String message = 'Access forbidden.',
    super.prefix = 'Access Forbidden',
    super.code,
    super.data,
  }) : super(message);
}

class InvalidInputException extends AppException {
  const InvalidInputException({
    String message = 'Invalid input provided.',
    super.prefix = 'Input Error',
    super.code,
    super.data,
  }) : super(message);
}

class FetchDataException extends AppException {
  const FetchDataException({
    String message = 'Unable to fetch data.',
    super.prefix = 'Fetch Error',
    super.code,
    super.data,
  }) : super(message);
}

class CustomException extends AppException {
  const CustomException({
    required String message,
    super.prefix = 'Custom Status',
    super.code,
    super.data,
  }) : super(message);
}

class NotFoundException extends AppException {
  const NotFoundException({
    String message = 'Resource not found.',
    super.prefix = 'Not Found',
    super.code,
    super.data,
  }) : super(message);
}

class UnknownException extends AppException {
  const UnknownException({
    String message = 'An unknown error occurred.',
    super.prefix = 'Unknown',
    super.code,
    super.data,
  }) : super(message);
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
    AccessForbiddenException _ => AccessForbiddenFailure(message, code, data),
    _ => UnknownFailure(message, code, data),
  };
}
