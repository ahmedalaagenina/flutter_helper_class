import 'package:kassemha/core/networking/api_call_handler.dart';

abstract class UseCase<T, Params> {
  Future<Result<T>> call(Params params);
}

class NoParams {}
