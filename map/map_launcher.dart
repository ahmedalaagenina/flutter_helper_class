import 'package:flutter/widgets.dart';
import 'package:idara_tracking_app/core/widgets/app_snack_bars.dart';
import 'package:idara_tracking_app/generated/l10n.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hands a coordinate to whatever the device uses for maps.
///
/// Shared because three screens need it — the device sheet, the event detail,
/// and history — and each was otherwise building its own URI list.
///
/// Every method tries a native scheme first and falls back to the web, so a
/// handset without Google Maps still gets somewhere. Nothing throws: a device
/// with no maps app at all gets a snack bar rather than a crash.
abstract final class MapLauncher {
  /// Turn-by-turn navigation **to** the point.
  ///
  /// ⛔ Not `geo:` — that opens a pin, not a route, which is what the device
  /// sheet's "Directions" link used to do on Android while doing the right
  /// thing on iOS. `google.navigation:` is the Android intent that actually
  /// starts navigation.
  static Future<void> directions(
    BuildContext context, {
    required double latitude,
    required double longitude,
  }) => _open(context, [
    Uri.parse('google.navigation:q=$latitude,$longitude'),
    Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$latitude,$longitude',
    ),
    Uri.parse('https://maps.apple.com/?daddr=$latitude,$longitude'),
  ]);

  /// The point itself, dropped as a pin — no route, no navigation.
  ///
  /// What an operator wants when the question is "where is it", rather than
  /// "how do I drive there".
  static Future<void> showPoint(
    BuildContext context, {
    required double latitude,
    required double longitude,
    String? label,
  }) {
    final name = label == null ? '' : '(${Uri.encodeComponent(label)})';

    return _open(context, [
      Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude$name'),
      Uri.parse(
        'https://www.google.com/maps/search/?api=1'
        '&query=$latitude,$longitude',
      ),
      Uri.parse('https://maps.apple.com/?ll=$latitude,$longitude&q=$label'),
    ]);
  }

  /// Street View at the point.
  ///
  /// Google only — there is no Apple equivalent, so a device with neither
  /// Google Maps nor a browser gets the snack bar.
  static Future<void> streetView(
    BuildContext context, {
    required double latitude,
    required double longitude,
  }) => _open(context, [
    Uri.parse('google.streetview:cbll=$latitude,$longitude'),
    Uri.parse(
      'https://www.google.com/maps/@?api=1&map_action=pano'
      '&viewpoint=$latitude,$longitude',
    ),
  ]);

  /// Opens the OS share sheet with a link anyone can open.
  ///
  /// A plain `maps.google.com` URL rather than a `geo:` scheme: the recipient
  /// may be on a desktop, on WhatsApp Web, or on a phone with no maps app, and
  /// a scheme URI is dead text to all three.
  static Future<void> sharePoint(
    BuildContext context, {
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    final strings = S.of(context);
    final link =
        'https://www.google.com/maps/search/?api=1'
        '&query=$latitude,$longitude';

    // The name first so the message reads as something, not as a bare URL.
    final message = label == null ? link : '$label\n$link';

    try {
      await SharePlus.instance.share(
        ShareParams(text: message, subject: label),
      );
    } on Object catch (_) {
      if (context.mounted) {
        AppSnackBars.warning(strings.couldNotOpenMaps, context: context);
      }
    }
  }

  /// Tries each candidate in order and stops at the first that opens.
  static Future<void> _open(BuildContext context, List<Uri> candidates) async {
    final strings = S.of(context);

    for (final uri in candidates) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (context.mounted) {
      AppSnackBars.warning(strings.couldNotOpenMaps, context: context);
    }
  }
}
