import 'package:dio/dio.dart';
import 'package:idara_esign/generated/l10n.dart';

class CustomInterceptor extends Interceptor {
  CustomInterceptor();

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    DioException transformedError = err;

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
        transformedError = err.copyWith(message: S.current.connectionTimeout);
        break;

      case DioExceptionType.sendTimeout:
        transformedError = err.copyWith(message: S.current.requestTimeout);
        break;

      case DioExceptionType.receiveTimeout:
        transformedError = err.copyWith(
          message: S.current.serverTooLongToRespond,
        );
        break;

      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        String message;

        switch (statusCode) {
          case 400:
            message = S.current.badRequestCheckInput;
            break;
          case 401:
            message = S.current.unauthorizedPleaseLogin;
            break;
          case 403:
            message = S.current.accessForbidden;
            break;
          case 404:
            message = S.current.resourceNotFound;
            break;
          case 500:
            message = S.current.serverErrorTryLater;
            break;
          case 503:
            message = S.current.serviceUnavailableTryLater;
            break;
          default:
            message =
                err.response?.data?['message'] ??
                S.current.genericErrorTryAgain;
        }

        transformedError = err.copyWith(message: message);
        break;

      case DioExceptionType.cancel:
        transformedError = err.copyWith(message: S.current.requestCancelled);
        break;

      case DioExceptionType.unknown:
        transformedError = err.copyWith(
          message: S.current.networkErrorCheckConnection,
        );
        break;

      default:
        transformedError = err.copyWith(message: S.current.unexpectedError);
    }

    handler.next(transformedError);
  }
}
