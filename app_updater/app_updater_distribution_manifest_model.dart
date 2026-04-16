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

  Map<TargetPlatform, String?> get downloadUrls {
    return {
      TargetPlatform.android: android?.downloadUrl,
      TargetPlatform.iOS: iOS?.downloadUrl,
      TargetPlatform.macOS: macOS?.downloadUrl,
      TargetPlatform.windows: windows?.downloadUrl,
      TargetPlatform.linux: linux?.downloadUrl,
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
  const AppUpdaterStatusDetails({required this.active, required this.message});

  final bool active;
  final Map<String?, dynamic>? message;

  factory AppUpdaterStatusDetails.fromJson(Map<String, dynamic> json) {
    final rawMessage = json['message'];
    return AppUpdaterStatusDetails(
      active: json['active'] as bool? ?? true,
      message: rawMessage is Map
          ? Map<String?, dynamic>.from(rawMessage)
          : null,
    );
  }

  String? getMessageForLanguage(String code) => message?[code];
}
