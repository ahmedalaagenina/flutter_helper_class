import 'package:flutter/foundation.dart';

class AppUpdaterDistributionManifest {
  const AppUpdaterDistributionManifest({
    this.android,
    this.iOS,
    this.macOS,
    this.windows,
    this.linux,
  });

  final AppUpdaterPlatformDistributionInfo? android;
  final AppUpdaterPlatformDistributionInfo? iOS;
  final AppUpdaterPlatformDistributionInfo? macOS;
  final AppUpdaterPlatformDistributionInfo? windows;
  final AppUpdaterPlatformDistributionInfo? linux;

  factory AppUpdaterDistributionManifest.fromJson(Map<String, dynamic> json) {
    return AppUpdaterDistributionManifest(
      android: json['android'] != null
          ? AppUpdaterPlatformDistributionInfo.fromJson(
              Map<String, dynamic>.from(json['android'] as Map),
            )
          : null,
      iOS: json['iOS'] != null
          ? AppUpdaterPlatformDistributionInfo.fromJson(
              Map<String, dynamic>.from(json['iOS'] as Map),
            )
          : json['ios'] != null
          ? AppUpdaterPlatformDistributionInfo.fromJson(
              Map<String, dynamic>.from(json['ios'] as Map),
            )
          : null,
      macOS: json['macOS'] != null
          ? AppUpdaterPlatformDistributionInfo.fromJson(
              Map<String, dynamic>.from(json['macOS'] as Map),
            )
          : json['macos'] != null
          ? AppUpdaterPlatformDistributionInfo.fromJson(
              Map<String, dynamic>.from(json['macos'] as Map),
            )
          : null,
      windows: json['windows'] != null
          ? AppUpdaterPlatformDistributionInfo.fromJson(
              Map<String, dynamic>.from(json['windows'] as Map),
            )
          : null,
      linux: json['linux'] != null
          ? AppUpdaterPlatformDistributionInfo.fromJson(
              Map<String, dynamic>.from(json['linux'] as Map),
            )
          : null,
    );
  }

  AppUpdaterPlatformDistributionInfo? get currentPlatform {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => iOS,
      TargetPlatform.macOS => macOS,
      TargetPlatform.windows => windows,
      TargetPlatform.linux => linux,
      _ => null,
    };
  }
}

class AppUpdaterPlatformDistributionInfo {
  const AppUpdaterPlatformDistributionInfo({
    required this.downloadUrl,
    required this.version,
    required this.status,
  });

  final AppUpdaterVersionDetails version;
  final String? downloadUrl;
  final AppUpdaterStatusDetails status;

  factory AppUpdaterPlatformDistributionInfo.fromJson(
    Map<String, dynamic> json,
  ) {
    return AppUpdaterPlatformDistributionInfo(
      version: AppUpdaterVersionDetails.fromJson(
        Map<String, dynamic>.from(json['version'] as Map),
      ),
      downloadUrl: json['download_url'] as String?,
      status: AppUpdaterStatusDetails.fromJson(
        Map<String, dynamic>.from(json['status'] as Map),
      ),
    );
  }
}

class AppUpdaterVersionDetails {
  const AppUpdaterVersionDetails({required this.minimum, required this.latest});

  final String minimum;
  final String latest;

  factory AppUpdaterVersionDetails.fromJson(Map<String, dynamic> json) {
    return AppUpdaterVersionDetails(
      minimum: json['minimum'].toString(),
      latest: json['latest'].toString(),
    );
  }
}

class AppUpdaterStatusDetails {
  const AppUpdaterStatusDetails({
    required this.maintenance,
    required this.message,
  });

  final bool maintenance;
  final Map<String, String>? message;

  factory AppUpdaterStatusDetails.fromJson(Map<String, dynamic> json) {
    final rawMessage = json['message'];
    final rawMaintenance = json['maintenance'];
    return AppUpdaterStatusDetails(
      maintenance: rawMaintenance as bool? ?? false,
      message: rawMessage is Map
          ? rawMessage.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : null,
    );
  }

  String? getMessageForLanguage(String code, {String fallbackCode = 'en'}) {
    final messages = message;
    if (messages == null || messages.isEmpty) return null;

    return messages[code] ??
        messages[code.split('-').first] ??
        messages[fallbackCode] ??
        messages[fallbackCode.split('-').first] ??
        messages.values.first;
  }
}
