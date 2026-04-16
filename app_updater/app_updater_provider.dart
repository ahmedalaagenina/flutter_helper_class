import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import 'app_updater.dart';

abstract class AppUpdaterProvider {
  Future<AppUpdaterDistributionManifest?> getDistributionManifest();
}

class RestfulAppUpdaterProvider extends AppUpdaterProvider {
  RestfulAppUpdaterProvider({required this.url, Dio? dio, this.headers})
    : _dio = dio ?? Dio();

  final String url;
  final Map<String, String>? headers;
  final Dio _dio;

  @override
  Future<AppUpdaterDistributionManifest?> getDistributionManifest() async {
    final response = await _dio.get<dynamic>(
      url,
      options: Options(headers: headers),
    );

    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      throw Exception(
        'Failed to fetch app updater config. Status code: $statusCode',
      );
    }

    final dynamic responseData = response.data;
    final dynamic body = responseData is String
        ? jsonDecode(responseData)
        : responseData;
    if (body is! Map<String, dynamic>) {
      throw const FormatException(
        'App updater response must be a JSON object.',
      );
    }

    return AppUpdaterDistributionManifest.fromJson(body);
  }
}

class MapAppUpdaterProvider extends AppUpdaterProvider {
  MapAppUpdaterProvider({required this.payload});

  final Map<String, dynamic> payload;

  @override
  Future<AppUpdaterDistributionManifest?> getDistributionManifest() async {
    return AppUpdaterDistributionManifest.fromJson(payload);
  }
}

class JsonStringAppUpdaterProvider extends AppUpdaterProvider {
  JsonStringAppUpdaterProvider({required this.jsonString});

  final String jsonString;

  @override
  Future<AppUpdaterDistributionManifest?> getDistributionManifest() async {
    final payload = jsonDecode(jsonString) as Map<String, dynamic>;
    return AppUpdaterDistributionManifest.fromJson(payload);
  }
}

class AssetJsonAppUpdaterProvider extends AppUpdaterProvider {
  AssetJsonAppUpdaterProvider({required this.assetPath});

  final String assetPath;

  @override
  Future<AppUpdaterDistributionManifest?> getDistributionManifest() async {
    final jsonString = await rootBundle.loadString(assetPath);
    final payload = jsonDecode(jsonString) as Map<String, dynamic>;
    return AppUpdaterDistributionManifest.fromJson(payload);
  }
}

class AppUpdaterMaintenanceModeProvider extends AppUpdaterProvider {
  @override
  Future<AppUpdaterDistributionManifest?> getDistributionManifest() async {
    return const AppUpdaterDistributionManifest(
      android: AppUpdaterPlatformDistributionInfo(
        downloadUrl: 'https://play.google.com',
        version: AppUpdaterVersionDetails(minimum: '1.0.0', latest: '2.0.0'),
        status: AppUpdaterStatusDetails(
          active: false,
          message: {
            'en': 'We are performing scheduled maintenance. Back in 30 min.',
            'ar': 'نحن نجري صيانة مجدولة. سنعود خلال 30 دقيقة.',
          },
        ),
      ),
      iOS: AppUpdaterPlatformDistributionInfo(
        downloadUrl: 'https://apps.apple.com',
        version: AppUpdaterVersionDetails(minimum: '1.0.0', latest: '2.0.0'),
        status: AppUpdaterStatusDetails(
          active: false,
          message: {
            'en': 'We are performing scheduled maintenance. Back in 30 min.',
            'ar': 'نحن نجري صيانة مجدولة. سنعود خلال 30 دقيقة.',
          },
        ),
      ),
    );
  }
}
