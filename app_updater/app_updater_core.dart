import 'package:flutter/foundation.dart';
import 'package:idara_esign/core/app_updater/app_updater.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:url_launcher/url_launcher.dart';

enum AppUpdaterStatus { outdated, forcedUpdate, upToDate, maintenance, unknown }

class AppUpdaterResult {
  AppUpdaterResult(this.status, {this.manifest});

  final AppUpdaterStatus status;
  final AppUpdaterDistributionManifest? manifest;

  String? getMessageForLanguage(String code, {String fallbackCode = 'en'}) {
    return manifest?.currentPlatform?.status.getMessageForLanguage(
      code,
      fallbackCode: fallbackCode,
    );
  }

  String? get downloadUrl => manifest?.currentPlatform?.downloadUrl;

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
    String? currentVersion,
  }) async {
    try {
      final manifest = await provider.getDistributionManifest();

      if (manifest == null) {
        return AppUpdaterResult(AppUpdaterStatus.unknown);
      }

      final storeDetails = manifest.currentPlatform;
      if (storeDetails == null) {
        return AppUpdaterResult(AppUpdaterStatus.unknown, manifest: manifest);
      }

      if (storeDetails.status.maintenance) {
        return AppUpdaterResult(
          AppUpdaterStatus.maintenance,
          manifest: manifest,
        );
      }

      // Web always runs the latest deployed build — store version
      // comparison is meaningless there; only the maintenance flag applies.
      if (kIsWeb) {
        return AppUpdaterResult(AppUpdaterStatus.upToDate, manifest: manifest);
      }

      final version = currentVersion ?? (await packageInfo).version;
      final platformVersion = Version.parse(version);
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

  static Future<void> launchDownloadUrl(String? url) async {
    if (url == null || url.isEmpty) return;

    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
