import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_updater.dart';

enum AppUpdaterStatus { outdated, forcedUpdate, upToDate, inactive, unknown }

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

    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
