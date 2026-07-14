import 'package:flutter/foundation.dart';

class AppUpdaterDistributionManifest {
  const AppUpdaterDistributionManifest({
    this.android,
    this.iOS,
    this.macOS,
    this.windows,
    this.linux,
    this.web,
  });

  final AppUpdaterPlatformDistributionInfo? android;
  final AppUpdaterPlatformDistributionInfo? iOS;
  final AppUpdaterPlatformDistributionInfo? macOS;
  final AppUpdaterPlatformDistributionInfo? windows;
  final AppUpdaterPlatformDistributionInfo? linux;
  final AppUpdaterPlatformDistributionInfo? web;

  factory AppUpdaterDistributionManifest.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) {
      return const AppUpdaterDistributionManifest();
    }
    return AppUpdaterDistributionManifest(
      android: data['android'] != null
          ? AppUpdaterPlatformDistributionInfo.fromJson(
              Map<String, dynamic>.from(data['android'] as Map),
            )
          : null,
      iOS: data['iOS'] != null
          ? AppUpdaterPlatformDistributionInfo.fromJson(
              Map<String, dynamic>.from(data['iOS'] as Map),
            )
          : data['ios'] != null
          ? AppUpdaterPlatformDistributionInfo.fromJson(
              Map<String, dynamic>.from(data['ios'] as Map),
            )
          : null,
      macOS: data['macOS'] != null
          ? AppUpdaterPlatformDistributionInfo.fromJson(
              Map<String, dynamic>.from(data['macOS'] as Map),
            )
          : data['macos'] != null
          ? AppUpdaterPlatformDistributionInfo.fromJson(
              Map<String, dynamic>.from(data['macos'] as Map),
            )
          : null,
      windows: data['windows'] != null
          ? AppUpdaterPlatformDistributionInfo.fromJson(
              Map<String, dynamic>.from(data['windows'] as Map),
            )
          : null,
      linux: data['linux'] != null
          ? AppUpdaterPlatformDistributionInfo.fromJson(
              Map<String, dynamic>.from(data['linux'] as Map),
            )
          : null,
      web: data['web'] != null
          ? AppUpdaterPlatformDistributionInfo.fromJson(
              Map<String, dynamic>.from(data['web'] as Map),
            )
          : null,
    );
  }

  AppUpdaterPlatformDistributionInfo? get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => iOS,
      TargetPlatform.macOS => macOS,
      TargetPlatform.windows => windows,
      TargetPlatform.linux => linux,
      _ => null,
    };
  }

  @override
  String toString() {
    return 'AppUpdaterDistributionManifest{android: $android, iOS: $iOS, macOS: $macOS, windows: $windows, linux: $linux}';
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
      version: json['version'] is Map
          ? AppUpdaterVersionDetails.fromJson(
              Map<String, dynamic>.from(json['version'] as Map),
            )
          : const AppUpdaterVersionDetails(minimum: '0.0.0', latest: '0.0.0'),
      downloadUrl: json['download_url'] as String?,
      status: AppUpdaterStatusDetails.fromJson(
        Map<String, dynamic>.from(json['status'] as Map),
      ),
    );
  }

  @override
  String toString() {
    return 'AppUpdaterPlatformDistributionInfo{version: $version, downloadUrl: $downloadUrl, status: $status}';
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

  @override
  String toString() {
    return 'AppUpdaterVersionDetails{minimum: $minimum, latest: $latest}';
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

  @override
  String toString() {
    return 'AppUpdaterStatusDetails{maintenance: $maintenance, message: $message}';
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
