import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';

import 'breakpoints.dart';

extension ContextMedia on BuildContext {
  Size get size => MediaQuery.sizeOf(this);
  double get width => size.width;
  double get height => size.height;
  double get shortestSide => size.shortestSide;

  EdgeInsets get padding => MediaQuery.paddingOf(this);
  EdgeInsets get viewPadding => MediaQuery.viewPaddingOf(this);
  EdgeInsets get viewInsets => MediaQuery.viewInsetsOf(this);

  double get topSafe => viewPadding.top;
  double get bottomSafe => viewPadding.bottom;

  double get keyboardInset => viewInsets.bottom;
  bool get isKeyboardOpen => keyboardInset > 0;

  Orientation get orientation => MediaQuery.orientationOf(this);
  bool get isLandscape => orientation == Orientation.landscape;
  bool get isPortrait => orientation == Orientation.portrait;
  double get textScaleFactor => MediaQuery.textScalerOf(this).scale(1);
  double get devicePixelRatio => MediaQuery.devicePixelRatioOf(this);

  bool get isMobileLayout => width < kMobileBreakPoint;
  bool get isBiggerThanMobile => width >= kMobileBreakPoint;

  bool get isTabletLayout =>
      width >= kMobileBreakPoint && width <= kDesktopBreakPoint;

  bool get isBiggerThanTablet => width > kTabletBreakpoint;
  bool get isSmallerThanTablet => width <= kTabletBreakpoint;

  bool get isDesktopLayout => width > kDesktopBreakPoint;
}

extension ContextPlatform on BuildContext {
  bool get isWeb => kIsWeb;

  bool get isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get isMobilePlatform => !kIsWeb && (isIOS || isAndroid);

  bool get isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
  bool get isWebOnMac =>
      kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  bool get isWebOnWindows =>
      kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  bool get isLinux => !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  bool get isWebOnLinux =>
      kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  bool get isDesktopPlatform => !kIsWeb && (isMacOS || isWindows || isLinux);

  bool get isCupertinoStyle => isIOS || isMacOS;
}
