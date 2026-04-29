import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:idara_esign/core/services/logger_service.dart';

abstract class INetworkInfoService {
  Future<String?> getNetworkType();
}

class NetworkInfoService implements INetworkInfoService {
  final Connectivity _connectivity;

  NetworkInfoService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  @override
  Future<String?> getNetworkType() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        return results.first.name;
      }
      return null;
    } catch (e) {
      AppLog.e('Failed to get network type: $e');
      return null;
    }
  }
}
