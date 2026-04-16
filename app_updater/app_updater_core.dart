import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:url_launcher/url_launcher.dart';

enum AppUpdaterStatus {
  outdated,
  forcedUpdate,
  upToDate,
  inactive,
  unknown,
}

class AppUpdaterResult {
  AppUpdaterResult(this.status, {this.manifest});

  final AppUpdaterStatus status;
  final AppUpdaterDistributionManifest? manifest;

  String? getMessageForLanguage(String code) {
    return manifest?.currentPlatform?.status.getMessageForLanguage(code);
  }

  Map<TargetPlatform, String?>? get downloadUrls => manifest?.downloadUrls;

  @override
  String toString() => 'status: $status, manifest: $manifest';
}

abstract class AppUpdaterProvider {
  Future<AppUpdaterDistributionManifest?> getDistributionManifest();
}

class RestfulAppUpdaterProvider extends AppUpdaterProvider {
  RestfulAppUpdaterProvider({
    required this.url,
    Dio? dio,
    this.headers,
  }) : _dio = dio ?? Dio();

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
      throw const FormatException('App updater response must be a JSON object.');
    }

    return AppUpdaterDistributionManifest.fromJson(body);
  }
}

class AppUpdater {
  static PackageInfo? _packageInfo;

  static Future<PackageInfo> get packageInfo async {
    _packageInfo ??= await PackageInfo.fromPlatform();
    return _packageInfo!;
  }

  static Future<AppUpdaterResult> check({
    required AppUpdaterProvider provider,
    bool silent = false,
  }) async {
    try {
      final info = await packageInfo;
      final platformVersion = Version.parse(info.version);
      final manifest = await provider.getDistributionManifest();

      if (manifest == null) {
        return AppUpdaterResult(AppUpdaterStatus.unknown);
      }

      final storeDetails = manifest.currentPlatform;
      if (storeDetails == null) {
        return AppUpdaterResult(AppUpdaterStatus.unknown, manifest: manifest);
      }

      if (!storeDetails.status.active) {
        return AppUpdaterResult(AppUpdaterStatus.inactive, manifest: manifest);
      }

      final minimumVersion = Version.parse(storeDetails.version.minimum);
      final latestVersion = Version.parse(storeDetails.version.latest);
      final minimumDifference = platformVersion.compareTo(minimumVersion);
      final latestDifference = platformVersion.compareTo(latestVersion);

      final status = minimumDifference.isNegative
          ? AppUpdaterStatus.forcedUpdate
          : latestDifference.isNegative
              ? AppUpdaterStatus.outdated
              : AppUpdaterStatus.upToDate;

      return AppUpdaterResult(status, manifest: manifest);
    } catch (error, stackTrace) {
      if (!silent) {
        debugPrint('[AppUpdater] check failed: $error\n$stackTrace');
      }
      return AppUpdaterResult(AppUpdaterStatus.unknown);
    }
  }

  static Future<void> launchDownloadUrl(
    Map<TargetPlatform, String?> data,
  ) async {
    final platform = defaultTargetPlatform;
    final url = data[platform];
    if (url == null || url.isEmpty) return;

    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }
}

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
  const AppUpdaterVersionDetails({
    required this.minimum,
    required this.latest,
  });

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
    required this.active,
    required this.message,
  });

  final bool active;
  final Map<String?, dynamic>? message;

  factory AppUpdaterStatusDetails.fromJson(Map<String, dynamic> json) {
    final rawMessage = json['message'];
    return AppUpdaterStatusDetails(
      active: json['active'] as bool? ?? true,
      message: rawMessage is Map ? Map<String?, dynamic>.from(rawMessage) : null,
    );
  }

  String? getMessageForLanguage(String code) => message?[code];
}
