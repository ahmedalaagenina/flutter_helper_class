import 'package:flutter/material.dart';

/// Shows any widget inside a realistic phone: a dark body, a rounded screen,
/// a camera island, side buttons and a soft shadow, all drawn in code (no
/// image assets), so it stays crisp at any size.
///
/// ```dart
/// PhoneFrame(
///   width: 280,
///   glowColor: Colors.teal,
///   screen: Image.asset('assets/screens/home.png', fit: BoxFit.cover),
/// );
/// ```
///
/// * [screen] fills the display and is clipped to its rounded corners. The
///   phone is `width * aspectRatio` tall; to reserve space before building,
///   use `width * PhoneFrame.defaultAspectRatio`.
/// * Performance: the frame and the screen each sit in their own
///   [RepaintBoundary]. A changing screen never repaints the blurred
///   shadows, and a parent `Transform` (tilt, parallax) moves the frame
///   without repainting it. Turn on [lowCost] when several phones move at
///   once.
/// * Accessibility: the frame adds no semantics of its own, so the screen's
///   content stays readable. Wrap it in `ExcludeSemantics` yourself when the
///   screen is only an illustration.
/// * The body stays dark in light and dark themes, like real hardware; only
///   the shadow strength follows the theme brightness.
class PhoneFrame extends StatelessWidget {
  /// Creates a phone mockup around [screen].
  const PhoneFrame({
    super.key,
    required this.screen,
    this.width = 300,
    this.aspectRatio = defaultAspectRatio,
    this.bodyColor = const Color(0xFF1A1F2B),
    this.borderColor = const Color(0xFF353D50),
    this.sideButtonColor = const Color(0xFF2B3243),
    this.islandColor = const Color(0xFF000000),
    this.shadowColor = const Color(0xFF000000),
    this.glow = true,
    this.glowColor,
    this.lowCost = false,
    this.showIsland = true,
    this.showSideButtons = true,
  }) : assert(width > 0, 'PhoneFrame.width must be greater than 0.'),
       assert(
         aspectRatio > 0,
         'PhoneFrame.aspectRatio must be greater than 0.',
       );

  /// Height divided by width of a current 6.1" phone, rounded.
  ///
  /// Public so a layout can reserve the phone's height before building it:
  /// `width * PhoneFrame.defaultAspectRatio`.
  static const double defaultAspectRatio = 2.12;

  /// What the phone shows. It is sized to fill the display exactly and is
  /// clipped to the display's rounded corners.
  final Widget screen;

  /// Outer width of the body in logical pixels. The bezel, corners, island
  /// and shadows all scale with it.
  final double width;

  /// Height divided by width. Defaults to [defaultAspectRatio].
  final double aspectRatio;

  /// Colour of the body (the bezel around the screen).
  final Color bodyColor;

  /// Colour of the thin rim along the body's edge.
  final Color borderColor;

  /// Colour of the action, volume and power buttons on the sides.
  final Color sideButtonColor;

  /// Colour of the camera island at the top of the screen.
  final Color islandColor;

  /// Base colour of the drop shadow. The frame sets its opacity: stronger
  /// on dark themes, where a faint shadow would disappear.
  final Color shadowColor;

  /// Soft coloured light under the phone. Turn it off for small thumbnails.
  final bool glow;

  /// Colour of the [glow]. Defaults to the theme's primary colour. The frame
  /// sets its opacity.
  final Color? glowColor;

  /// Replaces the two large blurred shadows with one small one, tinted by
  /// [glowColor] when [glow] is on and neutral otherwise.
  ///
  /// Use it when several phones move on screen at once (for example tilting
  /// cards in a scrolling list): CanvasKit on the web has no raster cache,
  /// so a moving phone redraws its blurs on every frame.
  final bool lowCost;

  /// Whether to draw the camera island over the top of the screen.
  final bool showIsland;

  /// Whether to draw the buttons on the sides of the body.
  final bool showSideButtons;

  // Side buttons as (top, length) in fractions of the height, plus the side
  // they sit on (true = left).
  static const List<(double, double, bool)> _sideButtons = [
    (0.17, 0.05, true), // action
    (0.25, 0.09, true), // volume up
    (0.36, 0.09, true), // volume down
    (0.27, 0.14, false), // power
  ];

  // Rim width in logical pixels. It is painted inside the body's edge.
  static const double _rimWidth = 1.2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Every size is a fraction of [width], so the frame scales as one piece.
    final height = width * aspectRatio;
    final bezel = width * 0.034;
    final outerRadius = width * 0.16;
    final innerRadius = outerRadius - bezel;
    final buttonThickness = (width * 0.0135).clamp(2.0, 6.0);
    final islandHeight = width * 0.085;

    // Own layer for the frame: its shadows are recorded once and reused
    // while a parent Transform moves the phone.
    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Drawn first so the body covers their inner half.
            if (showSideButtons)
              for (final (top, length, onLeft) in _sideButtons)
                Positioned(
                  top: height * top,
                  left: onLeft ? -buttonThickness / 2 : null,
                  right: onLeft ? null : -buttonThickness / 2,
                  width: buttonThickness,
                  height: height * length,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: sideButtonColor,
                      borderRadius: BorderRadius.circular(buttonThickness / 2),
                    ),
                  ),
                ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: bodyColor,
                  borderRadius: BorderRadius.circular(outerRadius),
                  border: Border.all(color: borderColor, width: _rimWidth),
                  boxShadow: _shadows(
                    glowColor ?? theme.colorScheme.primary,
                    isDark: isDark,
                  ),
                ),
                child: Padding(
                  // The rim is painted inside the body, so the display
                  // starts after bezel + rim.
                  padding: EdgeInsets.all(bezel + _rimWidth),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(innerRadius),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Own layer for the screen: its changes never
                        // repaint the frame's blurred shadows.
                        RepaintBoundary(child: screen),
                        if (showIsland)
                          Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: EdgeInsets.only(top: width * 0.03),
                              child: SizedBox(
                                width: width * 0.3,
                                height: islandHeight,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: islandColor,
                                    borderRadius: BorderRadius.circular(
                                      islandHeight / 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BoxShadow> _shadows(Color glowBase, {required bool isDark}) {
    final drop = BoxShadow(
      color: shadowColor.withValues(alpha: isDark ? 0.45 : 0.2),
      blurRadius: width * 0.1,
      offset: Offset(0, width * 0.06),
    );
    if (lowCost) {
      return [
        if (glow)
          BoxShadow(
            color: glowBase.withValues(alpha: isDark ? 0.18 : 0.12),
            blurRadius: width * 0.12,
            offset: Offset(0, width * 0.06),
          )
        else
          drop,
      ];
    }
    return [
      if (glow)
        BoxShadow(
          color: glowBase.withValues(alpha: isDark ? 0.22 : 0.16),
          blurRadius: width * 0.3,
          spreadRadius: -width * 0.04,
          offset: Offset(0, width * 0.12),
        ),
      drop,
    ];
  }
}
