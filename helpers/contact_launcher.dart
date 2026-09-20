import 'package:flutter/material.dart';
import 'package:idara_tracking_app/core/util/phone_number.dart';
import 'package:idara_tracking_app/core/widgets/widgets.dart';
import 'package:idara_tracking_app/generated/l10n.dart';
import 'package:url_launcher/url_launcher.dart';


abstract final class ContactLauncher {
  static bool canWhatsApp(String? rawPhone) =>
      PhoneNumber.forWhatsApp(rawPhone) != null;

  static bool canCall(String? rawPhone) =>
      PhoneNumber.forDialer(rawPhone) != null;

  static Future<void> call(BuildContext context, String? rawPhone) async {
    final number = PhoneNumber.forDialer(rawPhone);
    if (number == null) return;

    await _open(context, Uri(scheme: 'tel', path: number));
  }

  static Future<void> whatsApp(BuildContext context, String? rawPhone) async {
    final number = PhoneNumber.forWhatsApp(rawPhone);
    if (number == null) return;

    // wa.me over the whatsapp:// scheme on purpose: it works whether or not the
    // app is installed, falling back to the web client rather than failing.
    await _open(context, Uri.parse('https://wa.me/$number'));
  }

  static Future<void> _open(BuildContext context, Uri uri) async {
    final strings = S.of(context);

    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } on Object catch (_) {
      // Falls through to the same message: from the operator's side "the
      // dialer refused" and "the dialer threw" are the same problem.
    }

    if (context.mounted) {
      AppSnackBars.warning(strings.couldNotOpenContact, context: context);
    }
  }
}
abstract final class PhoneNumber {
  static const String defaultCountryCode = '966';
  static const int _minDigits = 8;
  static const int _maxDigits = 15;

  static String? forDialer(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;

    final cleaned = text.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.replaceAll('+', '').length < _minDigits) return null;

    return cleaned;
  }

  static String? forWhatsApp(
    String? raw, {
    String countryCode = defaultCountryCode,
  }) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;

    var digits = text.replaceAll(RegExp(r'[^\d+]'), '');
    final typed = digits.replaceAll('+', '');
    if (typed.length < _minDigits || typed.length > _maxDigits) return null;

    if (digits.startsWith('+')) {
      digits = digits.substring(1);
    } else if (digits.startsWith('00')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      digits = '$countryCode${digits.substring(1)}';
    } else if (!digits.startsWith(countryCode)) {
      digits = '$countryCode$digits';
    }

    if (digits.contains('+')) return null;
    if (digits.length < _minDigits || digits.length > _maxDigits) return null;

    return digits;
  }
}
