import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:idara_driver/core/networking/networking.dart';

/// ============================================================
/// ASYNC RESULT
/// ============================================================
///
/// Represents async request state:
/// - initial  → not started
/// - loading  → in progress
/// - success  → has data
/// - failure  → has error
///
/// Supports [previousData] to preserve UI during refresh/failure.
sealed class AsyncResult<T> extends Equatable {
  const AsyncResult();

  ///
  /// final result = const AsyncResult<User>.initial();
  ///
  const factory AsyncResult.initial() = AsyncResultInitial<T>;

  ///
  /// // first load
  /// AsyncResult.loading()
  ///
  /// Accepts optional [previousData] to preserve existing content during a reload.
  /// // refresh
  /// AsyncResult.loading(previousData: oldData)
  ///
  const factory AsyncResult.loading({T? previousData}) = AsyncResultLoading<T>;

  ///
  /// AsyncResult.success(data)
  ///
  const factory AsyncResult.success(T data) = AsyncResultSuccess<T>;

  ///
  /// AsyncResult.failure(error)
  ///
  /// Accepts optional [previousData] to preserve existing content alongside the error.
  /// AsyncResult.failure(error, previousData: oldData)
  ///
  const factory AsyncResult.failure(AppFailure error, {T? previousData}) =
      AsyncResultFailure<T>;

  /// Basic state checks
  bool get isInitial => this is AsyncResultInitial<T>;
  bool get isLoading => this is AsyncResultLoading<T>;
  bool get isSuccess => this is AsyncResultSuccess<T>;
  bool get isFailure => this is AsyncResultFailure<T>;

  /// Whether usable data exists (from a success state or preserved previous data).
  /// if (result.hasData) print(result.data);
  ///
  bool get hasData => data != null;

  /// Whether an error is currently present.
  /// if (result.hasError) print(result.error!.message);
  ///
  bool get hasError => error != null;

  /// Loading with existing data (refresh)
  /// Whether the operation is loading but retains previous data (e.g., Pull-to-refresh).
  /// if (result.isRefreshing) showTopLoader();
  bool get isRefreshing => isLoading && data != null;

  /// Failure with existing data
  /// Whether the operation failed but retains previous data.
  /// if (result.isReloadFailure) showErrorBanner();
  bool get isReloadFailure => isFailure && data != null;

  /// First load (no data yet)
  /// Whether the operation is loading for the first time (no previous data).
  /// if (result.isFirstLoading) showFullLoader();
  bool get isFirstLoading => isLoading && data == null;

  /// Returns:
  /// - success data
  /// - or previousData (loading/failure)
  /// - or null
  ///
  /// final data = result.data;
  ///
  T? get data => switch (this) {
    AsyncResultSuccess<T>(data: final value) => value,
    AsyncResultLoading<T>(previousData: final value) => value,
    AsyncResultFailure<T>(previousData: final value) => value,
    _ => null,
  };

  ///
  /// final error = result.error;
  ///
  AppFailure? get error => switch (this) {
    AsyncResultFailure<T>(error: final value) => value,
    _ => null,
  };

  /// Exhaustive handling
  ///
  /// result.when(
  ///   initial: () {},
  ///   loading: (_) {},
  ///   success: (data) {},
  ///   failure: (e, _) {},
  /// );
  ///
  R when<R>({
    required R Function() initial,
    required R Function(T? previousData) loading,
    required R Function(T data) success,
    required R Function(AppFailure error, T? previousData) failure,
  }) {
    return switch (this) {
      AsyncResultInitial<T>() => initial(),
      AsyncResultLoading<T>(previousData: final previousData) => loading(
        previousData,
      ),
      AsyncResultSuccess<T>(data: final data) => success(data),
      AsyncResultFailure<T>(
        error: final error,
        previousData: final previousData,
      ) =>
        failure(error, previousData),
    };
  }

  /// Partial handling
  ///
  /// final isLoading = result.maybeWhen(
  ///   loading: (_) => true,
  ///   orElse: () => false,
  /// );
  ///
  R maybeWhen<R>({
    R Function()? initial,
    R Function(T? previousData)? loading,
    R Function(T data)? success,
    R Function(AppFailure error, T? previousData)? failure,
    required R Function() orElse,
  }) {
    return switch (this) {
      AsyncResultInitial<T>() => initial?.call() ?? orElse(),
      AsyncResultLoading<T>(previousData: final previousData) =>
        loading?.call(previousData) ?? orElse(),
      AsyncResultSuccess<T>(data: final data) =>
        success?.call(data) ?? orElse(),
      AsyncResultFailure<T>(
        error: final error,
        previousData: final previousData,
      ) =>
        failure?.call(error, previousData) ?? orElse(),
    };
  }

  /// Transform data while keeping state
  ///
  /// final nameResult = result.mapData((u) => u.name);
  ///
  AsyncResult<R> mapData<R>(R Function(T data) mapper) {
    return switch (this) {
      AsyncResultInitial<T>() => AsyncResult<R>.initial(),
      AsyncResultLoading<T>(previousData: final previousData) =>
        AsyncResult<R>.loading(
          previousData: previousData != null ? mapper(previousData) : null,
        ),
      AsyncResultSuccess<T>(data: final data) => AsyncResult<R>.success(
        mapper(data),
      ),
      AsyncResultFailure<T>(
        error: final error,
        previousData: final previousData,
      ) =>
        AsyncResult<R>.failure(
          error,
          previousData: previousData != null ? mapper(previousData) : null,
        ),
    };
  }

  @override
  List<Object?> get props => [];
}

/// States
final class AsyncResultInitial<T> extends AsyncResult<T> {
  const AsyncResultInitial();
}

final class AsyncResultLoading<T> extends AsyncResult<T> {
  final T? previousData;

  const AsyncResultLoading({this.previousData});

  @override
  List<Object?> get props => [previousData];
}

final class AsyncResultSuccess<T> extends AsyncResult<T> {
  final T data;

  const AsyncResultSuccess(this.data);

  @override
  List<Object?> get props => [data];
}

final class AsyncResultFailure<T> extends AsyncResult<T> {
  final AppFailure error;
  final T? previousData;

  const AsyncResultFailure(this.error, {this.previousData});

  @override
  List<Object?> get props => [error, previousData];
}

/// ============================================================
/// EXTENSIONS (Bloc helpers)
/// ============================================================
extension AsyncResultX<T> on AsyncResult<T> {
  /// Transitions to the loading state while carrying over existing data.
  /// emit(state.copyWith(result: state.result.toLoading()));
  AsyncResult<T> toLoading() {
    return AsyncResult.loading(previousData: data);
  }

  /// Transitions to the failure state while carrying over existing data.
  /// emit(state.copyWith(result: state.result.toFailure(error)));
  AsyncResult<T> toFailure(AppFailure error) {
    return AsyncResult.failure(error, previousData: data);
  }

  /// Force-unwraps the data. Throws a [StateError] if no data exists.
  /// final data = result.requireData();
  T requireData() {
    final value = data;
    if (value == null) {
      throw StateError('AsyncResult does not contain data.');
    }
    return value;
  }
}

/// ============================================================
/// ASYNC RESULT BUILDER (UI)
/// ============================================================
///
/// Standard UI rendering for AsyncResult.
///
/// AsyncResultBuilder<User>(
///   result: state.userResult,
///   success: (user) => UserView(user),
/// )
///
class AsyncResultBuilder<T> extends StatelessWidget {
  /// The asynchronous result to evaluate.
  final AsyncResult<T> result;

  /// Builder for the initial state. Defaults to [SizedBox.shrink].
  final Widget Function()? initial;

  /// Builder for the first-time loading state. Defaults to [CircularProgressIndicator].
  final Widget Function()? loading;

  /// Required builder for the success state.
  final Widget Function(T data) success;

  /// Builder for the failure state. Defaults to displaying the error message.
  final Widget Function(AppFailure error)? failure;

  /// Builder for a loading state that retains previous data.
  final Widget Function(T data)? refreshing;

  /// Builder for a failure state that retains previous data.
  final Widget Function(T data, AppFailure error)? reloadFailure;

  const AsyncResultBuilder({
    super.key,
    required this.result,
    required this.success,
    this.initial,
    this.loading,
    this.failure,
    this.refreshing,
    this.reloadFailure,
  });

  @override
  Widget build(BuildContext context) {
    return switch (result) {
      AsyncResultInitial() => initial?.call() ?? const SizedBox.shrink(),

      AsyncResultLoading(previousData: final previousData) =>
        previousData != null
            ? (refreshing?.call(previousData) ?? success(previousData))
            : (loading?.call() ??
                  const Center(child: CircularProgressIndicator())),

      AsyncResultSuccess(data: final data) => success(data),

      AsyncResultFailure(
        error: final error,
        previousData: final previousData,
      ) =>
        previousData != null
            ? (reloadFailure?.call(previousData, error) ??
                  success(previousData))
            : (failure?.call(error) ?? Center(child: Text(error.message))),
    };
  }
}
