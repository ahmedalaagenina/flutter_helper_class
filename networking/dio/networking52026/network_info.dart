import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

abstract class NetworkInfo {
  /// Cheap OS-level check: "is some transport claimed up?"
  /// Lies on captive portals (hotel/airport Wi-Fi).
  Future<bool> get isConnected;

  /// Truthful check: actually reach a known host. Use this as the gate
  /// for offline-sync or before expensive uploads. One round-trip slower.
  Future<bool> get hasInternetAccess;

  /// Stream that emits connectivity status changes from the OS.
  Stream<bool> get onConnectivityChanged;
}

class NetworkInfoImpl implements NetworkInfo {
  final Connectivity connectivity;

  /// Host to probe for [hasInternetAccess]. Defaults to Cloudflare's
  /// always-on 1.1.1.1 service. Override for an internal endpoint
  /// when running on a closed network.
  final Uri pingUrl;

  /// Timeout for the reachability probe.
  final Duration pingTimeout;

  NetworkInfoImpl({
    Connectivity? connectivity,
    Uri? pingUrl,
    this.pingTimeout = const Duration(seconds: 3),
  }) : connectivity = connectivity ?? Connectivity(),
       pingUrl = pingUrl ?? Uri.parse('https://1.1.1.1');

  @override
  Future<bool> get isConnected async {
    final result = await connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none) && result.isNotEmpty;
  }

  @override
  Future<bool> get hasInternetAccess async {
    // Fast-fail if the OS reports no transport.
    if (!await isConnected) return false;

    // On web we can't open a raw socket; browsers handle captive portals
    // themselves, so the connectivity result is the best we've got.
    if (kIsWeb) return true;

    try {
      final client = HttpClient()..connectionTimeout = pingTimeout;
      final request = await client.headUrl(pingUrl).timeout(pingTimeout);
      final response = await request.close().timeout(pingTimeout);
      client.close(force: true);
      // Any HTTP response (even 4xx/5xx) proves the network is reachable.
      return response.statusCode > 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<bool> get onConnectivityChanged {
    return connectivity.onConnectivityChanged.map((results) {
      return !results.contains(ConnectivityResult.none) && results.isNotEmpty;
    });
  }
}
