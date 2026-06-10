import 'package:flutter/widgets.dart';
import 'package:idara_esign/core/biometric_auth/service/biometric_auth.dart';
import 'package:idara_esign/core/widgets/app_snack_bars.dart';
import 'package:idara_esign/di/injection_container.dart';
import 'package:idara_esign/generated/l10n.dart';

/// Best-effort biometric / device-credential gate, shown before a sensitive
/// action such as submitting signatures to the backend.
///
/// This is the app-level glue between the reusable, platform-agnostic
/// [BiometricAuthService] (in `core/biometric_auth/`) and this app's
/// localization + snackbars. The core module stays free of app dependencies so
/// it can be copied into other projects untouched.
///
/// Returns `true` when the caller should proceed:
/// - the user authenticated successfully, or
/// - local authentication is unavailable on this device/browser. We do **not**
///   lock users out when there is no biometric/PIN enrolled (see
///   [BiometricAuthUnavailable]).
///
/// Returns `false` — and surfaces a localized message — when the user actively
/// cancels, fails, is locked out, or an unexpected error occurs.
class BiometricSignGate {
  const BiometricSignGate._();

  static Future<bool> confirm(BuildContext context, {String? reason}) async {
    final service = getIt<BiometricAuthService>();
    final result = await service.authenticate(
      localizedReason: reason ?? S.of(context).biometricSignReason,
    );

    // The prompt is async; bail out gracefully if the screen is gone.
    if (!context.mounted) return result.isSuccess;

    switch (result) {
      case BiometricAuthSuccess():
        return true;
      case BiometricAuthCanceled():
      case BiometricAuthFailed():
        AppSnackBars.warning(
          S.of(context).biometricRequiredToContinue,
          context: context,
        );
        return false;
      case BiometricAuthLockedOut():
        AppSnackBars.error(S.of(context).biometricLockedOut, context: context);
        return false;
      case BiometricAuthError():
        AppSnackBars.error(
          S.of(context).biometricAuthErrorTryAgain,
          context: context,
        );
        return false;
      case BiometricAuthUnavailable():
        return false;
    }
  }
}
