import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum AppInstallerStore { googlePlay, appStore, unknown }

extension PrettyMapJson on Map<String, dynamic> {
  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(this);
  }
}

@immutable
class AppPackageInfo extends PackageInfo {
  AppPackageInfo({
    required super.appName,
    required super.packageName,
    required super.version,
    required super.buildNumber,
    required super.buildSignature,
    required super.installerStore,
    required super.installTime,
    required super.updateTime,
  });

  bool get hasInstallerStore =>
      installerStore != null && installerStore!.trim().isNotEmpty;

  bool get hasBuildSignature => buildSignature.trim().isNotEmpty;

  String get fullVersion => '$version+$buildNumber';

  AppInstallerStore get installerStoreType {
    final value = installerStore?.toLowerCase().trim();

    if (value == null || value.isEmpty) {
      return AppInstallerStore.unknown;
    }

    if (value.contains('google')) {
      return AppInstallerStore.googlePlay;
    }

    if (value.contains('apple') || value.contains('app_store')) {
      return AppInstallerStore.appStore;
    }

    return AppInstallerStore.unknown;
  }

  Map<String, dynamic> toJson() {
    return {
      'appName': appName,
      'packageName': packageName,
      'version': version,
      'buildNumber': buildNumber,
      'fullVersion': fullVersion,
      'buildSignature': buildSignature,
      'installerStore': installerStore,
      'installerStoreType': installerStoreType.name,
      'installTime': installTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
      'hasInstallerStore': hasInstallerStore,
      'hasBuildSignature': hasBuildSignature,
    };
  }

  String toPrettyString() => toJson().toPrettyJson();

  void printPretty() {
    debugPrint(toPrettyString());
  }

  @override
  String toString() => toPrettyString();
}
