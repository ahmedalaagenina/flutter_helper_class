import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idara_esign/core/networking/networking.dart';

abstract class BaseBloc<Event, State> extends Bloc<Event, State> {
  BaseBloc(super.initialState);

  Future<void> safeHandle<T>({
    required Result<T> result,
    required FutureOr<void> Function(T data) onSuccess,
    required FutureOr<void> Function(AppFailure failure) onFailure,
  }) {
    return result.fold(
      (failure) async {
        if (failure is DuplicateRequestFailure) return;
        await onFailure(failure);
      },
      (data) async {
        await onSuccess(data);
      },
    );
  }
}
