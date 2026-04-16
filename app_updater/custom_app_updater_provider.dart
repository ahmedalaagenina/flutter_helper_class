import 'dart:convert';

import 'package:flutter/services.dart';

import 'app_updater_core.dart';

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
