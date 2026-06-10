import 'package:flutter/material.dart';
import 'package:idara_esign/config/theme/theme.dart';
import 'package:idara_esign/core/biometric_auth/service/biometric_auth.dart';
import 'package:idara_esign/core/constants/storage_keys.dart';
import 'package:idara_esign/di/injection_container.dart';
import 'package:idara_esign/generated/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockWidget extends StatefulWidget {
  const AppLockWidget({super.key});

  @override
  State<AppLockWidget> createState() => _AppLockWidgetState();
}

class _AppLockWidgetState extends State<AppLockWidget> {
  bool _useBiometricAuth = false;
  bool _isSupported = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final authService = getIt<BiometricAuthService>();
    final isSupported = await authService.isSupported();
    final hasEnrolledBiometrics = await authService.hasEnrolledBiometrics();
    final prefs = getIt<SharedPreferences>();
    setState(() {
      _isSupported = isSupported && hasEnrolledBiometrics;
      _useBiometricAuth = prefs.getBool(StorageKeys.useBiometricAuth) ?? false;
    });
  }

  Future<void> _toggleBiometricAuth(bool value) async {
    final authService = getIt<BiometricAuthService>();
    final result = await authService.authenticate(
      localizedReason: S.current.requireBiometricDescription,
    );
    if (!result.isSuccess) {
      return; // Do not enable if authentication fails
    }
    final prefs = getIt<SharedPreferences>();
    await prefs.setBool(StorageKeys.useBiometricAuth, value);
    setState(() {
      _useBiometricAuth = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupported) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.security, color: context.colors.primary),
            const SizedBox(width: 12),
            Text(S.of(context).security, style: context.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.outline.withOpacity(0.1)),
          ),
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              S.of(context).requireBiometric,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              S.of(context).requireBiometricDescription,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.onSurfaceVariant.withOpacity(0.8),
              ),
            ),
            value: _useBiometricAuth,
            onChanged: _toggleBiometricAuth,
            activeColor: context.colors.primary,
          ),
        ),
      ],
    );
  }
}
