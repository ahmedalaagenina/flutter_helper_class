import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:idara_driver/features/auth/presentation/bloc/auth_bloc.dart';

class AuthRouterRefreshNotifier extends ChangeNotifier {
  AuthRouterRefreshNotifier(this._authBloc) {
    _lastStatus = _authBloc.state.status;
    _subscription = _authBloc.stream.listen((state) {
      if (state.status == _lastStatus) return;
      _lastStatus = state.status;
      notifyListeners();
    });
    Future<void>.microtask(notifyListeners);
  }

  void notify() => notifyListeners();

  final AuthBloc _authBloc;
  late AuthStatus _lastStatus;
  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
