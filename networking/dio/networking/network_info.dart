import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

abstract class NetworkInfo {
  Future<bool> get isConnected;

  /// Stream that emits connectivity status changes.
  Stream<bool> get onConnectivityChanged;
}

class NetworkInfoImpl implements NetworkInfo {
  final Connectivity connectivity;

  NetworkInfoImpl({Connectivity? connectivity})
    : connectivity = connectivity ?? Connectivity();

  @override
  Future<bool> get isConnected async {
    final result = await connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none) && result.isNotEmpty;
  }

  @override
  Stream<bool> get onConnectivityChanged {
    return connectivity.onConnectivityChanged.map((results) {
      return !results.contains(ConnectivityResult.none) && results.isNotEmpty;
    });
  }
}
