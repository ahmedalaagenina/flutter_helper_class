import '../networking/api_call_handler.dart';

abstract class UseCase<T, Params> {
  Future<T> call(Params params);
}

class NoParams {}

/// Abstract base class for all use cases
/// [T]: Return type of the use case (usually Entity)
/// [Params]: Parameters required for the use case
abstract class BaseUseCase<T, Params> {
  /// Execute the use case
  Future<Result<T>> call(Params params);
}

/// Use case with no parameters
class NoParams {
  const NoParams();
}
