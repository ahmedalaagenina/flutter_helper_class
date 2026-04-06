import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:kassemha/config/router/routes.dart';

class AuthRouterRefreshNotifier extends ChangeNotifier {
  AuthRouterRefreshNotifier(this._authBloc) {
    _subscription = _authBloc.stream.listen((_) => notifyListeners());
    Future<void>.microtask(notifyListeners);
  }

  void notify() => notifyListeners();

  final AuthBloc _authBloc;
  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
