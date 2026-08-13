import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idara_tracking_app/core/constants/app_constants.dart';
import 'package:idara_tracking_app/core/local_storage/local_storage.dart';
import 'package:idara_tracking_app/generated/l10n.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'locale_state.dart';

@injectable
class LocaleCubit extends Cubit<LocaleState> {
  final SharedPreferences storage;

  LocaleCubit(this.storage)
    : super(LocaleState(locale: _systemLocale(), isLoading: true)) {
    init();
  }

  /// Call this once after creating the cubit
  Future<void> init() async {
    final savedLocaleCode = storage.getString(StorageKeys.locale);
    final saved = savedLocaleCode == null
        ? null
        : Locale(_normalizeLocaleCode(savedLocaleCode));

    final locale = saved != null && _isSupported(saved)
        ? saved
        : _systemLocale();

    emit(state.copyWith(locale: locale, isLoading: true));
    await S.load(locale);

    emit(state.copyWith(isLoading: false));
  }

  Future<void> setLocale(String localeCode) async {
    final newLocale = Locale(_normalizeLocaleCode(localeCode));
    if (!S.delegate.supportedLocales.contains(newLocale)) return;

    emit(state.copyWith(locale: newLocale, isLoading: true));
    await S.load(newLocale);
    await storage.setString(StorageKeys.locale, newLocale.languageCode);

    emit(state.copyWith(isLoading: false));
    // var context = rootNavigatorKey.currentContext;
    // if (context != null && context.mounted) {
    //   AppLog.i('Restarting app');
    //   RestartWidget.restartApp(context);
    // }
  }

  Future<void> clearLocale() async {
    await storage.remove(StorageKeys.locale);

    final fallback = _systemLocale();
    emit(state.copyWith(locale: fallback, isLoading: true));

    if (S.delegate.supportedLocales.contains(fallback)) {
      await S.load(fallback);
    }

    emit(state.copyWith(isLoading: false));
  }

  static String _normalizeLocaleCode(String code) {
    final normalized = code.replaceAll('-', '_'); // ar-EG -> ar_EG
    return normalized.split('_').first; // ar_EG -> ar
  }

  static bool _isSupported(Locale locale) =>
      S.delegate.supportedLocales.contains(locale);

  static Locale _systemLocale() {
    for (final preferred
        in WidgetsBinding.instance.platformDispatcher.locales) {
      final candidate = Locale(preferred.languageCode);
      if (_isSupported(candidate)) return candidate;
    }

    return const Locale(AppConstants.englishLanguageCode);
  }
}
