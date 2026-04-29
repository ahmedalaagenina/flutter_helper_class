import 'package:idara_esign/core/services/package_info/package_info_model.dart';
import 'package:package_info_plus/package_info_plus.dart';

// getIt.registerLazySingleton<IPackageInfoService>(
//   () => const PackageInfoService(),
// );
// getIt.registerLazySingleton<PackageInfoManager>(
//   () => PackageInfoManager(getIt<IPackageInfoService>()),
// );

abstract class IPackageInfoService {
  Future<AppPackageInfo> getPackageInfo();
}

class PackageInfoService implements IPackageInfoService {
  const PackageInfoService();

  @override
  Future<AppPackageInfo> getPackageInfo() async {
    final info = await PackageInfo.fromPlatform();

    return AppPackageInfo(
      appName: info.appName,
      packageName: info.packageName,
      version: info.version,
      buildNumber: info.buildNumber,
      buildSignature: info.buildSignature,
      installerStore: info.installerStore,
      installTime: info.installTime,
      updateTime: info.updateTime,
    );
  }
}

class PackageInfoManager {
  final IPackageInfoService _service;

  AppPackageInfo? _cached;
  Future<AppPackageInfo>? _pending;

  PackageInfoManager(this._service);

  Future<AppPackageInfo> getPackageInfo() {
    if (_cached != null) {
      return Future.value(_cached!);
    }

    if (_pending != null) {
      return _pending!;
    }

    _pending = _service.getPackageInfo().then((value) {
      _cached = value;
      _pending = null;
      return value;
    });

    return _pending!;
  }

  void clearCache() {
    _cached = null;
    _pending = null;
  }
}
