import 'package:dio/dio.dart';
import 'package:idara_esign/core/services/logger_service.dart';

abstract class IIpInfoService {
  Future<String?> getIpAddress();
}

class IpInfoService implements IIpInfoService {
  final Dio _dio;

  IpInfoService({Dio? dio}) : _dio = dio ?? Dio();

  @override
  Future<String?> getIpAddress() async {
    try {
      final response = await _dio.get('https://api.ipify.org?format=json');
      return response.data['ip'] as String?;
    } catch (e) {
      AppLog.e('Failed to get IP address: $e');
      return null;
    }
  }
}
