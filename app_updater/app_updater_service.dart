import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'app_updater.dart';

typedef OnAppUpdaterResult = void Function(AppUpdaterResult result);
typedef OnAppUpdaterError = void Function(Object error, StackTrace? stack);

class AppUpdaterService {
  AppUpdaterService._();

  static final AppUpdaterService instance = AppUpdaterService._();

  AppUpdaterResult? _result;
  bool _initialized = false;
  bool _checking = false;

  AppUpdaterResult? get result => _result;
  bool get isInitialized => _initialized;
  bool get isChecking => _checking;
  bool get isInactive => _result?.status == AppUpdaterStatus.inactive;
  bool get isForcedUpdate => _result?.status == AppUpdaterStatus.forcedUpdate;
  bool get isOutdated => _result?.status == AppUpdaterStatus.outdated;
  bool get isUpToDate => _result?.status == AppUpdaterStatus.upToDate;

  Future<AppUpdaterResult?> init({
    AppUpdaterProviderType provider = AppUpdaterProviderType.restful,
    String? restfulUrl,
    Map<String, String>? restfulHeaders,
    Dio? dio,
    AppUpdaterProvider? customProvider,
    bool silent = false,
    String languageCode = 'en',
    OnAppUpdaterResult? onResult,
    OnAppUpdaterError? onError,
  }) async {
    if (_checking) return _result;

    _checking = true;

    try {
      final updaterProvider = _resolveProvider(
        type: provider,
        restfulUrl: restfulUrl,
        restfulHeaders: restfulHeaders,
        dio: dio,
        customProvider: customProvider,
      );

      _result = await AppUpdater.check(
        provider: updaterProvider,
        silent: silent,
      );

      _initialized = true;
      onResult?.call(_result!);

      if (!silent) {
        debugPrint(
          '[AppUpdaterService] Status: ${_result!.status} | '
          'Message (${languageCode.toUpperCase()}): '
          '${maintenanceMessage(languageCode) ?? "–"}',
        );
      }

      return _result;
    } catch (error, stackTrace) {
      _initialized = true;
      onError?.call(error, stackTrace);
      if (!silent) {
        debugPrint('[AppUpdaterService] Error: $error');
      }
      return null;
    } finally {
      _checking = false;
    }
  }

  Future<AppUpdaterResult?> recheck({
    AppUpdaterProviderType provider = AppUpdaterProviderType.restful,
    String? restfulUrl,
    Map<String, String>? restfulHeaders,
    Dio? dio,
    AppUpdaterProvider? customProvider,
    bool silent = false,
    String languageCode = 'en',
    OnAppUpdaterResult? onResult,
    OnAppUpdaterError? onError,
  }) {
    _initialized = false;
    return init(
      provider: provider,
      restfulUrl: restfulUrl,
      restfulHeaders: restfulHeaders,
      dio: dio,
      customProvider: customProvider,
      silent: silent,
      languageCode: languageCode,
      onResult: onResult,
      onError: onError,
    );
  }

  Future<void> launchStore() async {
    if (_result == null) return;
    try {
      await AppUpdater.launchDownloadUrl(_result!.downloadUrls!);
    } catch (e) {
      debugPrint('[AppUpdaterService] Could not launch store URL: $e');
    }
  }

  String? maintenanceMessage(String languageCode) {
    if (_result == null) return null;
    return _result!.getMessageForLanguage(languageCode);
  }

  AppUpdaterDistributionManifest? get manifest => _result?.manifest;

  @visibleForTesting
  void reset() {
    _result = null;
    _initialized = false;
    _checking = false;
  }

  AppUpdaterProvider _resolveProvider({
    required AppUpdaterProviderType type,
    String? restfulUrl,
    Map<String, String>? restfulHeaders,
    Dio? dio,
    AppUpdaterProvider? customProvider,
  }) {
    switch (type) {
      case AppUpdaterProviderType.restful:
        assert(
          restfulUrl != null && restfulUrl.isNotEmpty,
          '[AppUpdaterService] restfulUrl must be provided for the RESTful provider.',
        );
        return RestfulAppUpdaterProvider(
          url: restfulUrl!,
          dio: dio,
          headers: restfulHeaders,
        );
      case AppUpdaterProviderType.custom:
        assert(
          customProvider != null,
          '[AppUpdaterService] customProvider must not be null when using the custom provider type.',
        );
        return customProvider!;
    }
  }
}

enum AppUpdaterProviderType { restful, custom }
