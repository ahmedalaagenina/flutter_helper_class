// Brand logos from Simple Icons (https://simpleicons.org, CC0-1.0): each SVG
// path on its 24x24 grid, converted to Flutter Path calls. The artwork is
// public domain, but the logos are trademarks of their owners, so follow
// each brand's usage guidelines.
//
// Why paths instead of an icon font: Flutter web waits for every declared
// font before its first paint, while a Path is plain geometry in the code,
// so these icons never delay the first frame.
import 'package:flutter/widgets.dart';

/// The logos [BrandIcon] can draw.
enum Brand {
  /// The GitHub Octocat mark.
  gitHub,

  /// The Apple logo, for App Store links.
  apple,

  /// The Google Play triangle.
  googlePlay,

  /// The WhatsApp chat bubble.
  whatsApp,

  /// The LinkedIn "in" square.
  linkedIn,

  /// The Dart logo.
  dart,
}

/// Shows a brand logo (GitHub, Apple, Google Play, WhatsApp, LinkedIn or
/// Dart) in one colour, used just like an [Icon].
///
/// ```dart
/// TextButton.icon(
///   onPressed: openProfile,
///   icon: const BrandIcon(Brand.linkedIn),
///   label: Text(l10n.linkedInProfile),
/// );
/// ```
///
/// * Size and colour come from the surrounding [IconTheme], so the logo
///   matches a button's other icons, unless [size] or [color] is set.
/// * Decorative by default (wrapped in [ExcludeSemantics]): the button or
///   link around it should carry the label. Set [semanticLabel] only for a
///   logo that stands alone and means something.
/// * Each brand's [Path] is built once and shared by every instance. The
///   logo scales uniformly (never stretched) and never mirrors in
///   right-to-left layouts.
class BrandIcon extends StatelessWidget {
  /// Creates the logo of [brand].
  const BrandIcon(
    this.brand, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  }) : assert(
         size == null || size >= 0,
         'BrandIcon.size must not be negative.',
       );

  /// Which logo to draw.
  final Brand brand;

  /// Width and height in logical pixels. Defaults to the [IconTheme] size,
  /// like [Icon].
  final double? size;

  /// Fill colour. Defaults to the [IconTheme] colour.
  final Color? color;

  /// What a screen reader announces. Leave it null (decorative) when the
  /// surrounding button or link already names the brand, the usual case.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final size = this.size ?? iconTheme.size ?? 24.0;
    var color = this.color ?? iconTheme.color ?? const Color(0xFF000000);
    // Same rule as Icon: an IconTheme opacity fades the logo too.
    final opacity = iconTheme.opacity ?? 1.0;
    if (opacity < 1) color = color.withValues(alpha: color.a * opacity);

    final logo = ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _BrandPainter(brand, color),
      ),
    );
    final label = semanticLabel;
    if (label == null) return logo;
    return Semantics(container: true, image: true, label: label, child: logo);
  }
}

class _BrandPainter extends CustomPainter {
  const _BrandPainter(this.brand, this.color);

  final Brand brand;
  final Color color;

  // Paths are built once per brand, then reused by every icon instance.
  static final Map<Brand, Path> _cache = {};

  @override
  void paint(Canvas canvas, Size size) {
    final path = _cache.putIfAbsent(
      brand,
      () => switch (brand) {
        Brand.gitHub => _gitHub(),
        Brand.apple => _apple(),
        Brand.googlePlay => _googlePlay(),
        Brand.whatsApp => _whatsApp(),
        Brand.linkedIn => _linkedIn(),
        Brand.dart => _dart(),
      },
    );
    // One uniform scale from the 24x24 grid, centred: if a parent forces a
    // non-square box, the logo keeps its proportions instead of stretching.
    final scale = size.shortestSide / 24;
    canvas
      ..save()
      ..translate((size.width - 24 * scale) / 2, (size.height - 24 * scale) / 2)
      ..scale(scale)
      ..drawPath(path, Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(_BrandPainter oldDelegate) =>
      oldDelegate.brand != brand || oldDelegate.color != color;
}

// Path data below is copied unchanged from the Simple Icons SVGs.

Path _gitHub() => Path()
  ..moveTo(12, 0.297)
  ..cubicTo(5.37, 0.297, 0, 5.67, 0, 12.297)
  ..cubicTo(0, 17.6, 3.438, 22.097, 8.205, 23.682)
  ..cubicTo(8.805, 23.795, 9.025, 23.424, 9.025, 23.105)
  ..cubicTo(9.025, 22.82, 9.015, 22.065, 9.01, 21.065)
  ..cubicTo(5.672, 21.789, 4.968, 19.455, 4.968, 19.455)
  ..cubicTo(4.422, 18.07, 3.633, 17.7, 3.633, 17.7)
  ..cubicTo(2.546, 16.956, 3.717, 16.971, 3.717, 16.971)
  ..cubicTo(4.922, 17.055, 5.555, 18.207, 5.555, 18.207)
  ..cubicTo(6.625, 20.042, 8.364, 19.512, 9.05, 19.205)
  ..cubicTo(9.158, 18.429, 9.467, 17.9, 9.81, 17.6)
  ..cubicTo(7.145, 17.3, 4.344, 16.268, 4.344, 11.67)
  ..cubicTo(4.344, 10.36, 4.809, 9.29, 5.579, 8.45)
  ..cubicTo(5.444, 8.147, 5.039, 6.927, 5.684, 5.274)
  ..cubicTo(5.684, 5.274, 6.689, 4.952, 8.984, 6.504)
  ..cubicTo(9.944, 6.237, 10.964, 6.105, 11.984, 6.099)
  ..cubicTo(13.004, 6.105, 14.024, 6.237, 14.984, 6.504)
  ..cubicTo(17.264, 4.952, 18.269, 5.274, 18.269, 5.274)
  ..cubicTo(18.914, 6.927, 18.509, 8.147, 18.389, 8.45)
  ..cubicTo(19.154, 9.29, 19.619, 10.36, 19.619, 11.67)
  ..cubicTo(19.619, 16.28, 16.814, 17.295, 14.144, 17.59)
  ..cubicTo(14.564, 17.95, 14.954, 18.686, 14.954, 19.81)
  ..cubicTo(14.954, 21.416, 14.939, 22.706, 14.939, 23.096)
  ..cubicTo(14.939, 23.411, 15.149, 23.786, 15.764, 23.666)
  ..cubicTo(20.565, 22.092, 24, 17.592, 24, 12.297)
  ..cubicTo(24, 5.67, 18.627, 0.297, 12, 0.297)
  ..close();
Path _apple() => Path()
  ..moveTo(12.152, 6.896)
  ..cubicTo(11.204, 6.896, 9.737, 5.818, 8.192, 5.856)
  ..cubicTo(6.152, 5.883, 4.282, 7.039, 3.231, 8.87)
  ..cubicTo(1.114, 12.545, 2.685, 17.973, 4.75, 20.96)
  ..cubicTo(5.763, 22.414, 6.958, 24.05, 8.542, 23.999)
  ..cubicTo(10.062, 23.934, 10.632, 23.012, 12.477, 23.012)
  ..cubicTo(14.308, 23.012, 14.827, 23.999, 16.437, 23.96)
  ..cubicTo(18.074, 23.934, 19.113, 22.48, 20.113, 21.012)
  ..cubicTo(21.269, 19.324, 21.749, 17.687, 21.775, 17.597)
  ..cubicTo(21.736, 17.584, 18.593, 16.376, 18.555, 12.74)
  ..cubicTo(18.529, 9.7, 21.035, 8.246, 21.152, 8.181)
  ..cubicTo(19.723, 6.091, 17.529, 5.857, 16.762, 5.805)
  ..cubicTo(14.762, 5.649, 13.087, 6.895, 12.152, 6.895)
  ..lineTo(12.152, 6.896)
  ..close()
  ..moveTo(15.53, 3.83)
  ..cubicTo(16.373, 2.818, 16.93, 1.403, 16.775, 0)
  ..cubicTo(15.568, 0.052, 14.113, 0.805, 13.243, 1.818)
  ..cubicTo(12.463, 2.714, 11.789, 4.156, 11.97, 5.532)
  ..cubicTo(13.308, 5.636, 14.685, 4.844, 15.529, 3.831)
  ..close();
Path _googlePlay() => Path()
  ..moveTo(22.018, 13.298)
  ..lineTo(18.099, 15.516)
  ..lineTo(14.584, 12.023)
  ..lineTo(18.127, 8.502)
  ..lineTo(22.018, 10.704)
  ..cubicTo(22.486, 10.968, 22.775, 11.464, 22.775, 12.001)
  ..cubicTo(22.775, 12.538, 22.486, 13.034, 22.018, 13.298)
  ..lineTo(22.018, 13.298)
  ..close()
  ..moveTo(1.337, 0.924)
  ..cubicTo(1.263, 1.104, 1.225, 1.297, 1.225, 1.492)
  ..lineTo(1.225, 22.509)
  ..cubicTo(1.225, 22.726, 1.27, 22.928, 1.349, 23.109)
  ..lineTo(12.504, 12.022)
  ..lineTo(1.337, 0.924)
  ..close()
  ..moveTo(13.544, 10.989)
  ..lineTo(16.802, 7.751)
  ..lineTo(3.45, 0.195)
  ..cubicTo(3.164, 0.031, 2.83, -0.033, 2.504, 0.016)
  ..lineTo(13.544, 10.989)
  ..lineTo(13.544, 10.989)
  ..close()
  ..moveTo(13.544, 13.056)
  ..lineTo(2.544, 23.989)
  ..cubicTo(2.842, 24.025, 3.156, 23.973, 3.45, 23.806)
  ..lineTo(16.774, 16.266)
  ..lineTo(13.544, 13.056)
  ..lineTo(13.544, 13.056)
  ..close();
Path _whatsApp() => Path()
  ..moveTo(17.472, 14.382)
  ..cubicTo(17.175, 14.233, 15.714, 13.515, 15.442, 13.415)
  ..cubicTo(15.169, 13.316, 14.971, 13.267, 14.772, 13.565)
  ..cubicTo(14.575, 13.862, 14.005, 14.531, 13.832, 14.729)
  ..cubicTo(13.659, 14.928, 13.485, 14.952, 13.188, 14.804)
  ..cubicTo(12.891, 14.654, 11.933, 14.341, 10.798, 13.329)
  ..cubicTo(9.915, 12.541, 9.318, 11.568, 9.145, 11.27)
  ..cubicTo(8.972, 10.973, 9.127, 10.812, 9.275, 10.664)
  ..cubicTo(9.409, 10.531, 9.573, 10.317, 9.721, 10.144)
  ..cubicTo(9.87, 9.97, 9.919, 9.846, 10.019, 9.647)
  ..cubicTo(10.118, 9.449, 10.069, 9.276, 9.994, 9.127)
  ..cubicTo(9.919, 8.978, 9.325, 7.515, 9.078, 6.92)
  ..cubicTo(8.836, 6.341, 8.591, 6.42, 8.409, 6.41)
  ..cubicTo(8.236, 6.402, 8.038, 6.4, 7.839, 6.4)
  ..cubicTo(7.641, 6.4, 7.319, 6.474, 7.047, 6.772)
  ..cubicTo(6.775, 7.069, 6.007, 7.788, 6.007, 9.251)
  ..cubicTo(6.007, 10.713, 7.072, 12.126, 7.22, 12.325)
  ..cubicTo(7.369, 12.523, 9.316, 15.525, 12.297, 16.812)
  ..cubicTo(13.006, 17.118, 13.559, 17.301, 13.991, 17.437)
  ..cubicTo(14.703, 17.664, 15.351, 17.632, 15.862, 17.555)
  ..cubicTo(16.433, 17.47, 17.62, 16.836, 17.868, 16.142)
  ..cubicTo(18.116, 15.448, 18.116, 14.853, 18.041, 14.729)
  ..cubicTo(17.967, 14.605, 17.769, 14.531, 17.471, 14.382)
  ..close()
  ..moveTo(12.05, 21.785)
  ..lineTo(12.046, 21.785)
  ..cubicTo(10.276, 21.785, 8.538, 21.309, 7.015, 20.407)
  ..lineTo(6.654, 20.193)
  ..lineTo(2.913, 21.175)
  ..lineTo(3.911, 17.527)
  ..lineTo(3.676, 17.153)
  ..cubicTo(2.686, 15.577, 2.163, 13.754, 2.166, 11.893)
  ..cubicTo(2.167, 6.443, 6.602, 2.009, 12.054, 2.009)
  ..cubicTo(14.694, 2.009, 17.176, 3.039, 19.042, 4.907)
  ..cubicTo(20.902, 6.758, 21.943, 9.277, 21.935, 11.901)
  ..cubicTo(21.932, 17.351, 17.498, 21.785, 12.05, 21.785)
  ..close()
  ..moveTo(20.463, 3.488)
  ..cubicTo(18.237, 1.248, 15.208, -0.008, 12.05, 0)
  ..cubicTo(5.495, 0, 0.16, 5.335, 0.157, 11.892)
  ..cubicTo(0.157, 13.988, 0.704, 16.034, 1.745, 17.837)
  ..lineTo(0.057, 24)
  ..lineTo(6.362, 22.346)
  ..cubicTo(8.106, 23.296, 10.059, 23.794, 12.045, 23.794)
  ..lineTo(12.05, 23.794)
  ..cubicTo(18.604, 23.794, 23.94, 18.459, 23.943, 11.901)
  ..cubicTo(23.953, 8.745, 22.7, 5.715, 20.463, 3.488)
  ..lineTo(20.463, 3.488)
  ..close();
Path _linkedIn() => Path()
  ..moveTo(20.447, 20.452)
  ..lineTo(16.893, 20.452)
  ..lineTo(16.893, 14.883)
  ..cubicTo(16.893, 13.555, 16.866, 11.846, 15.041, 11.846)
  ..cubicTo(13.188, 11.846, 12.905, 13.291, 12.905, 14.785)
  ..lineTo(12.905, 20.452)
  ..lineTo(9.351, 20.452)
  ..lineTo(9.351, 9)
  ..lineTo(12.765, 9)
  ..lineTo(12.765, 10.561)
  ..lineTo(12.811, 10.561)
  ..cubicTo(13.288, 9.661, 14.448, 8.711, 16.181, 8.711)
  ..cubicTo(19.782, 8.711, 20.448, 11.081, 20.448, 14.166)
  ..lineTo(20.448, 20.452)
  ..lineTo(20.447, 20.452)
  ..close()
  ..moveTo(5.337, 7.433)
  ..cubicTo(4.193, 7.433, 3.274, 6.507, 3.274, 5.368)
  ..cubicTo(3.274, 4.23, 4.194, 3.305, 5.337, 3.305)
  ..cubicTo(6.477, 3.305, 7.401, 4.23, 7.401, 5.368)
  ..cubicTo(7.401, 6.507, 6.476, 7.433, 5.337, 7.433)
  ..close()
  ..moveTo(7.119, 20.452)
  ..lineTo(3.555, 20.452)
  ..lineTo(3.555, 9)
  ..lineTo(7.119, 9)
  ..lineTo(7.119, 20.452)
  ..close()
  ..moveTo(22.225, 0)
  ..lineTo(1.771, 0)
  ..cubicTo(0.792, 0, 0, 0.774, 0, 1.729)
  ..lineTo(0, 22.271)
  ..cubicTo(0, 23.227, 0.792, 24, 1.771, 24)
  ..lineTo(22.222, 24)
  ..cubicTo(23.2, 24, 24, 23.227, 24, 22.271)
  ..lineTo(24, 1.729)
  ..cubicTo(24, 0.774, 23.2, 0, 22.222, 0)
  ..lineTo(22.225, 0)
  ..close();
Path _dart() => Path()
  ..moveTo(4.105, 4.105)
  ..cubicTo(4.105, 4.105, 9.158, 1.58, 11.684, 0.316)
  ..cubicTo(12.144, 0.089, 12.653, -0.019, 13.165, 0.001)
  ..cubicTo(13.931, 0.048, 14.842, 0.789, 14.842, 0.789)
  ..lineTo(24, 9.948)
  ..lineTo(24, 19.737)
  ..lineTo(19.737, 19.737)
  ..lineTo(19.737, 24)
  ..lineTo(9.789, 24)
  ..lineTo(0.789, 15)
  ..cubicTo(0.303, 14.5, 0, 13.795, 0, 13.105)
  ..cubicTo(0, 12.786, 0.18, 12.287, 0.316, 12)
  ..lineTo(4.105, 4.105)
  ..close()
  ..moveTo(4.784, 4.784)
  ..lineTo(4.784, 16.571)
  ..cubicTo(4.786, 17.114, 4.805, 17.595, 5.282, 18.079)
  ..lineTo(10.204, 23)
  ..lineTo(18.737, 23)
  ..lineTo(18.737, 18.737)
  ..lineTo(4.784, 4.784)
  ..lineTo(4.784, 4.784)
  ..close()
  ..moveTo(16.839, 4.106)
  ..cubicTo(15.94, 3.21, 15.03, 2.326, 14.099, 1.463)
  ..cubicTo(13.797, 1.196, 13.532, 0.995, 13.029, 1.001)
  ..cubicTo(12.659, 1.015, 12.159, 1.196, 12.159, 1.196)
  ..lineTo(6.341, 4.105)
  ..lineTo(16.839, 4.106)
  ..close();
