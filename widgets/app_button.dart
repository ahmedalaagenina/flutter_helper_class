import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

typedef AsyncVoidCallback = Future<void> Function();

enum AppHaptic {
  none,
  light,
  medium,
  heavy;

  Future<void> vibrate() async {
    switch (this) {
      case AppHaptic.none:
        return;
      case AppHaptic.light:
        return HapticFeedback.lightImpact();
      case AppHaptic.medium:
        return HapticFeedback.mediumImpact();
      case AppHaptic.heavy:
        return HapticFeedback.heavyImpact();
    }
  }
}

enum _ButtonType { standard, text, iconText, icon, selection }

enum AppButtonAnimationType { none, scale, sizeAndColor }

class AppButton extends StatefulWidget {
  final _ButtonType _type;
  final Widget? child;
  final String? title;
  final IconData? icon;
  final String? svgAsset;
  final String? imageAsset;
  final VoidCallback? onPressed;
  final AsyncVoidCallback? onPressedAsync;
  final bool loading;
  final bool enabled;
  final bool visualOnly;
  final double? width;
  final double? height;
  final bool fitHeight;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final AlignmentGeometry alignment;
  final double radius;
  final bool isCircle;
  final BoxBorder? border;
  final Color? backgroundColor;
  final Color? disabledBackgroundColor;
  final Color? textColor;
  final Color? disabledTextColor;
  final Color? iconColor;
  final Color? disabledIconColor;
  final Gradient? gradient;
  final bool haveShadow;
  final Color? shadowColor;
  final double shadowBlurRadius;
  final Offset shadowOffset;
  final List<BoxShadow>? boxShadow;
  final AppHaptic haptic;
  final bool unfocusOnTap;
  final bool expandText;
  final bool haveFullWidth;
  final MainAxisAlignment mainAxisAlignment;
  final double? fontSize;
  final FontWeight? fontWeight;
  final bool inverseColor;
  final bool iconAtEnd;
  final bool centerTitle;
  final double spacing;
  final double iconSize;
  final double iconInset;
  final bool haveCircularIcon;
  final Color? circularIconColor;
  final double? circularIconRadius;
  final bool isSvgAssetColored;
  final bool isImageColored;
  final BlendMode colorBlendMode;
  final bool isSelected;
  final ValueChanged<bool>? onSelectionChanged;
  final Color activeColor;
  final Color inactiveColor;
  final AppButtonAnimationType animationType;
  final Duration animationDuration;

  const AppButton({
    super.key,
    required this.child,
    this.onPressed,
    this.onPressedAsync,
    this.loading = false,
    this.enabled = true,
    this.visualOnly = false,
    this.width,
    this.height = 48,
    this.fitHeight = false,
    this.padding,
    this.margin,
    this.alignment = Alignment.center,
    this.radius = 8,
    this.border,
    this.backgroundColor,
    this.disabledBackgroundColor,
    this.gradient,
    this.haveShadow = false,
    this.shadowColor,
    this.shadowBlurRadius = 10,
    this.shadowOffset = const Offset(0, 4),
    this.boxShadow,
    this.haptic = AppHaptic.medium,
    this.unfocusOnTap = true,
  }) : _type = _ButtonType.standard,
       isCircle = false,
       title = null,
       icon = null,
       svgAsset = null,
       imageAsset = null,
       textColor = null,
       disabledTextColor = null,
       iconColor = null,
       disabledIconColor = null,
       expandText = false,
       haveFullWidth = false,
       mainAxisAlignment = MainAxisAlignment.center,
       fontSize = null,
       fontWeight = null,
       inverseColor = false,
       iconAtEnd = false,
       centerTitle = false,
       spacing = 0,
       iconSize = 0,
       iconInset = 0,
       haveCircularIcon = false,
       circularIconColor = null,
       circularIconRadius = null,
       isSvgAssetColored = false,
       isImageColored = false,
       colorBlendMode = BlendMode.srcIn,
       isSelected = false,
       onSelectionChanged = null,
       activeColor = Colors.red,
       inactiveColor = Colors.grey,
       animationType = AppButtonAnimationType.none,
       animationDuration = const Duration(milliseconds: 300);

  const AppButton.text({
    super.key,
    required this.title,
    this.onPressed,
    this.onPressedAsync,
    this.loading = false,
    this.enabled = true,
    this.visualOnly = false,
    this.width,
    this.height = 48,
    this.fitHeight = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
    this.margin,
    this.alignment = Alignment.center,
    this.radius = 8,
    this.border,
    this.backgroundColor,
    this.disabledBackgroundColor,
    this.textColor,
    this.disabledTextColor,
    this.gradient,
    this.haveShadow = false,
    this.shadowColor,
    this.shadowBlurRadius = 10,
    this.shadowOffset = const Offset(0, 4),
    this.boxShadow,
    this.haptic = AppHaptic.medium,
    this.unfocusOnTap = true,
    this.expandText = false,
    this.haveFullWidth = true,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.fontSize,
    this.fontWeight,
    this.inverseColor = false,
  }) : _type = _ButtonType.text,
       isCircle = false,
       child = null,
       icon = null,
       svgAsset = null,
       imageAsset = null,
       iconColor = null,
       disabledIconColor = null,
       iconAtEnd = false,
       centerTitle = false,
       spacing = 0,
       iconSize = 0,
       iconInset = 0,
       haveCircularIcon = false,
       circularIconColor = null,
       circularIconRadius = null,
       isSvgAssetColored = false,
       isImageColored = false,
       colorBlendMode = BlendMode.srcIn,
       isSelected = false,
       onSelectionChanged = null,
       activeColor = Colors.red,
       inactiveColor = Colors.grey,
       animationType = AppButtonAnimationType.none,
       animationDuration = const Duration(milliseconds: 300);

  const AppButton.iconText({
    super.key,
    required this.title,
    this.icon,
    this.svgAsset,
    this.imageAsset,
    this.onPressed,
    this.onPressedAsync,
    this.loading = false,
    this.enabled = true,
    this.visualOnly = false,
    this.width,
    this.height = 48,
    this.fitHeight = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.margin,
    this.alignment = Alignment.center,
    this.radius = 8,
    this.border,
    this.backgroundColor,
    this.disabledBackgroundColor,
    this.textColor,
    this.disabledTextColor,
    this.iconColor,
    this.disabledIconColor,
    this.gradient,
    this.haveShadow = false,
    this.shadowColor,
    this.shadowBlurRadius = 10,
    this.shadowOffset = const Offset(0, 4),
    this.boxShadow,
    this.haptic = AppHaptic.medium,
    this.unfocusOnTap = true,
    this.haveFullWidth = true,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.fontSize,
    this.fontWeight,
    this.inverseColor = false,
    this.iconAtEnd = false,
    this.centerTitle = false,
    this.spacing = 8,
    this.iconSize = 20,
    this.iconInset = 16,
    this.haveCircularIcon = false,
    this.circularIconColor,
    this.circularIconRadius,
    this.isSvgAssetColored = true,
    this.isImageColored = true,
    this.colorBlendMode = BlendMode.srcIn,
  }) : assert(icon != null || svgAsset != null || imageAsset != null),
       _type = _ButtonType.iconText,
       isCircle = false,
       child = null,
       expandText = false,
       isSelected = false,
       onSelectionChanged = null,
       activeColor = Colors.red,
       inactiveColor = Colors.grey,
       animationType = AppButtonAnimationType.none,
       animationDuration = const Duration(milliseconds: 300);

  const AppButton.icon({
    super.key,
    required this.icon,
    this.onPressed,
    this.onPressedAsync,
    this.loading = false,
    this.enabled = true,
    this.visualOnly = false,
    double size = 48,
    this.padding,
    this.margin,
    this.radius = 8,
    this.border,
    this.backgroundColor,
    this.disabledBackgroundColor,
    this.iconColor,
    this.disabledIconColor,
    this.gradient,
    this.haveShadow = false,
    this.shadowColor,
    this.shadowBlurRadius = 10,
    this.shadowOffset = const Offset(0, 4),
    this.boxShadow,
    this.haptic = AppHaptic.medium,
    this.unfocusOnTap = true,
    this.iconSize = 24,
    this.isCircle = false,
  }) : _type = _ButtonType.icon,
       width = size,
       height = size,
       fitHeight = false,
       alignment = Alignment.center,
       title = null,
       svgAsset = null,
       imageAsset = null,
       child = null,
       textColor = null,
       disabledTextColor = null,
       expandText = false,
       haveFullWidth = false,
       mainAxisAlignment = MainAxisAlignment.center,
       fontSize = null,
       fontWeight = null,
       inverseColor = false,
       iconAtEnd = false,
       centerTitle = false,
       spacing = 0,
       iconInset = 0,
       haveCircularIcon = false,
       circularIconColor = null,
       circularIconRadius = null,
       isSvgAssetColored = false,
       isImageColored = false,
       colorBlendMode = BlendMode.srcIn,
       isSelected = false,
       onSelectionChanged = null,
       activeColor = Colors.red,
       inactiveColor = Colors.grey,
       animationType = AppButtonAnimationType.none,
       animationDuration = const Duration(milliseconds: 300);

  const AppButton.circleIcon({
    super.key,
    required this.icon,
    this.onPressed,
    this.onPressedAsync,
    this.loading = false,
    this.enabled = true,
    this.visualOnly = false,
    double size = 48,
    this.padding,
    this.margin,
    this.border,
    this.backgroundColor,
    this.disabledBackgroundColor,
    this.iconColor,
    this.disabledIconColor,
    this.gradient,
    this.haveShadow = false,
    this.shadowColor,
    this.shadowBlurRadius = 10,
    this.shadowOffset = const Offset(0, 4),
    this.boxShadow,
    this.haptic = AppHaptic.medium,
    this.unfocusOnTap = true,
    this.iconSize = 24,
  }) : _type = _ButtonType.icon,
       isCircle = true,
       width = size,
       height = size,
       fitHeight = false,
       radius = size / 2,
       alignment = Alignment.center,
       title = null,
       svgAsset = null,
       imageAsset = null,
       child = null,
       textColor = null,
       disabledTextColor = null,
       expandText = false,
       haveFullWidth = false,
       mainAxisAlignment = MainAxisAlignment.center,
       fontSize = null,
       fontWeight = null,
       inverseColor = false,
       iconAtEnd = false,
       centerTitle = false,
       spacing = 0,
       iconInset = 0,
       haveCircularIcon = false,
       circularIconColor = null,
       circularIconRadius = null,
       isSvgAssetColored = false,
       isImageColored = false,
       colorBlendMode = BlendMode.srcIn,
       isSelected = false,
       onSelectionChanged = null,
       activeColor = Colors.red,
       inactiveColor = Colors.grey,
       animationType = AppButtonAnimationType.none,
       animationDuration = const Duration(milliseconds: 300);

  const AppButton.animatedSelection({
    super.key,
    required this.isSelected,
    this.onSelectionChanged,
    required this.icon,
    this.onPressed,
    this.onPressedAsync,
    this.visualOnly = false,
    double buttonSize = 48,
    this.padding,
    this.margin,
    this.radius = 8,
    this.backgroundColor,
    this.disabledBackgroundColor,
    this.activeColor = Colors.red,
    this.inactiveColor = Colors.grey,
    this.iconSize = 24,
    this.haveShadow = false,
    this.shadowColor,
    this.shadowBlurRadius = 10,
    this.boxShadow,
    this.animationType = AppButtonAnimationType.sizeAndColor,
    this.animationDuration = const Duration(milliseconds: 500),
    this.isCircle = true,
  }) : _type = _ButtonType.selection,
       title = null,
       svgAsset = null,
       imageAsset = null,
       child = null,
       textColor = null,
       disabledTextColor = null,
       iconColor = null,
       disabledIconColor = null,
       width = buttonSize,
       height = buttonSize,
       fitHeight = false,
       alignment = Alignment.center,
       enabled = true,
       loading = false,
       haptic = AppHaptic.medium,
       unfocusOnTap = true,
       expandText = false,
       haveFullWidth = false,
       mainAxisAlignment = MainAxisAlignment.center,
       fontSize = null,
       fontWeight = null,
       inverseColor = false,
       iconAtEnd = false,
       centerTitle = false,
       spacing = 0,
       iconInset = 0,
       haveCircularIcon = false,
       circularIconColor = null,
       circularIconRadius = null,
       isSvgAssetColored = false,
       isImageColored = false,
       colorBlendMode = BlendMode.srcIn,
       shadowOffset = const Offset(0, 4),
       border = null,
       gradient = null;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> with TickerProviderStateMixin {
  bool _internalLoading = false;
  late bool _internalSelected;
  late AnimationController _sizeController;
  late AnimationController _colorController;
  late Animation<double> _sizeAnimation;
  late Animation<Color?> _colorAnimation;

  bool get _isLoading => widget.loading || _internalLoading;
  bool get _isEffectivelyEnabled =>
      !widget.visualOnly && widget.enabled && !_isLoading;

  @override
  void initState() {
    super.initState();
    _internalSelected = widget.isSelected;
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _sizeController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _colorController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    final double endScale = widget.animationType == AppButtonAnimationType.scale
        ? 1.3
        : 1.5;

    _sizeAnimation = Tween<double>(begin: 1.0, end: endScale).animate(
      CurvedAnimation(
        parent: _sizeController,
        curve: widget.animationType == AppButtonAnimationType.scale
            ? Curves.easeInOut
            : Curves.elasticOut,
      ),
    );

    _colorAnimation =
        ColorTween(
          begin: widget.inactiveColor,
          end: widget.activeColor,
        ).animate(
          CurvedAnimation(parent: _colorController, curve: Curves.easeInOut),
        );

    if (widget._type == _ButtonType.selection &&
        widget.animationType == AppButtonAnimationType.sizeAndColor) {
      _colorController.addStatusListener((status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          _sizeController.reverse();
        }
      });
      if (_internalSelected) {
        _colorController.value = 1.0;
      }
    }
  }

  @override
  void didUpdateWidget(AppButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget._type == _ButtonType.selection) {
      if (oldWidget.isSelected != widget.isSelected) {
        _internalSelected = widget.isSelected;
        if (widget.animationType == AppButtonAnimationType.sizeAndColor) {
          _internalSelected
              ? _colorController.forward()
              : _colorController.reverse();
        }
      }
      if (oldWidget.animationDuration != widget.animationDuration) {
        _sizeController.duration = widget.animationDuration;
        _colorController.duration = widget.animationDuration;
      }
    }
  }

  @override
  void dispose() {
    _sizeController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (!_isEffectivelyEnabled) return;
    if (widget.unfocusOnTap) FocusScope.of(context).unfocus();
    await widget.haptic.vibrate();

    if (widget._type == _ButtonType.selection) {
      _handleSelectionTap();
    } else {
      _handleStandardTap();
    }
  }

  void _handleSelectionTap() {
    if (widget.animationType == AppButtonAnimationType.sizeAndColor) {
      if (_internalSelected) {
        _sizeController.forward();
        _colorController.reverse();
      } else {
        _sizeController.forward();
        _colorController.forward();
      }
    } else if (widget.animationType == AppButtonAnimationType.scale) {
      _sizeController.forward().then((_) => _sizeController.reverse());
    }

    setState(() => _internalSelected = !_internalSelected);
    widget.onSelectionChanged?.call(_internalSelected);
    if (widget.onPressed != null) widget.onPressed!();
  }

  Future<void> _handleStandardTap() async {
    if (widget.onPressed != null) {
      widget.onPressed!();
      return;
    }
    if (widget.onPressedAsync != null) {
      setState(() => _internalLoading = true);
      try {
        await widget.onPressedAsync!();
      } finally {
        if (mounted) setState(() => _internalLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    final defaultBg = widget.inverseColor ? Colors.white : primaryColor;
    final bg = widget.backgroundColor ?? defaultBg;
    final disabledBg = widget.disabledBackgroundColor ?? Colors.grey.shade400;

    final materialColor = _isEffectivelyEnabled ? bg : disabledBg;
    final actualGradient = _isEffectivelyEnabled ? widget.gradient : null;
    final resolvedHeight = widget.fitHeight ? null : widget.height;
    final borderRadius = widget.isCircle
        ? BorderRadius.circular((widget.width ?? 48) / 2)
        : BorderRadius.circular(widget.radius);

    final shadowList =
        widget.boxShadow ??
        (widget.haveShadow && _isEffectivelyEnabled
            ? [
                BoxShadow(
                  color: (widget.shadowColor ?? Colors.black).withOpacity(0.15),
                  blurRadius: widget.shadowBlurRadius,
                  offset: widget.shadowOffset,
                ),
              ]
            : null);

    Widget buttonWrap = Container(
      width: widget.width,
      height: resolvedHeight,
      margin: widget.margin,
      decoration: BoxDecoration(
        gradient: actualGradient,
        borderRadius: borderRadius,
        border: widget.border,
        boxShadow: shadowList,
      ),
      child: Material(
        color: actualGradient != null ? Colors.transparent : materialColor,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _isEffectivelyEnabled || widget.visualOnly ? _handleTap : null,
          child: Container(
            width: widget.width,
            height: resolvedHeight,
            padding: widget.padding,
            alignment: widget.alignment,
            child: _isLoading ? _buildLoader() : _buildContent(theme),
          ),
        ),
      ),
    );

    if (widget.width == null && widget.haveFullWidth == false) {
      return IntrinsicWidth(child: buttonWrap);
    }
    return buttonWrap;
  }

  Widget _buildLoader() {
    return const SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator.adaptive(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    switch (widget._type) {
      case _ButtonType.standard:
        return widget.child ?? const SizedBox.shrink();

      case _ButtonType.text:
        return _buildTextWidget(theme);

      case _ButtonType.iconText:
        return _buildIconTextContent(theme);

      case _ButtonType.icon:
        return _buildIconWidget();

      case _ButtonType.selection:
        return _buildAnimatedFavoriteContent();
    }
  }

  Widget _buildIconTextContent(ThemeData theme) {
    final iconWidget = _buildIconWidget();
    final textWidget = _buildTextWidget(theme);
    final hasIcon =
        widget.icon != null ||
        widget.svgAsset != null ||
        widget.imageAsset != null;

    if (!widget.centerTitle) {
      return Row(
        mainAxisSize: widget.haveFullWidth
            ? MainAxisSize.max
            : MainAxisSize.min,
        mainAxisAlignment: widget.mainAxisAlignment,
        textDirection: widget.iconAtEnd ? TextDirection.rtl : TextDirection.ltr,
        children: [
          if (hasIcon) iconWidget,
          if (hasIcon) SizedBox(width: widget.spacing),
          widget.expandText
              ? Expanded(child: textWidget)
              : Flexible(child: textWidget),
        ],
      );
    } else {
      return Stack(
        alignment: Alignment.center,
        children: [
          if (hasIcon)
            PositionedDirectional(
              start: widget.iconAtEnd ? null : widget.iconInset,
              end: widget.iconAtEnd ? widget.iconInset : null,
              child: iconWidget,
            ),
          Center(child: textWidget),
        ],
      );
    }
  }

  Widget _buildAnimatedFavoriteContent() {
    final iconData = _internalSelected
        ? Icons.favorite_rounded
        : Icons.favorite_border_rounded;

    if (widget.animationType == AppButtonAnimationType.none) {
      return Icon(
        iconData,
        color: _internalSelected ? widget.activeColor : widget.inactiveColor,
        size: widget.iconSize,
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_sizeAnimation, _colorController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _sizeAnimation.value,
          child: Icon(
            iconData,
            color: widget.animationType == AppButtonAnimationType.sizeAndColor
                ? _colorAnimation.value
                : (_internalSelected
                      ? widget.activeColor
                      : widget.inactiveColor),
            size: widget.iconSize,
          ),
        );
      },
    );
  }

  Widget _buildTextWidget(ThemeData theme) {
    final primaryColor = theme.primaryColor;
    final defaultTextColor = widget.inverseColor ? primaryColor : Colors.white;
    final effectiveTextColor = _isEffectivelyEnabled
        ? (widget.textColor ?? defaultTextColor)
        : (widget.disabledTextColor ?? Colors.white70);

    return Text(
      widget.title ?? '',
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium?.copyWith(
        color: effectiveTextColor,
        fontSize: widget.fontSize,
        fontWeight: widget.fontWeight,
      ),
    );
  }

  Widget _buildIconWidget() {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final defaultIconColor = widget.inverseColor ? primaryColor : Colors.white;
    final effectiveIconColor = _isEffectivelyEnabled
        ? (widget.iconColor ?? defaultIconColor)
        : (widget.disabledIconColor ?? Colors.white70);

    Widget iconView = const SizedBox.shrink();

    if (widget.imageAsset != null) {
      iconView = Image.asset(
        widget.imageAsset!,
        width: widget.iconSize,
        height: widget.iconSize,
        color: widget.isImageColored ? effectiveIconColor : null,
        colorBlendMode: widget.isImageColored ? widget.colorBlendMode : null,
        fit: BoxFit.contain,
      );
    } else if (widget.svgAsset != null) {
      iconView = SvgPicture.asset(
        widget.svgAsset!,
        width: widget.iconSize,
        height: widget.iconSize,
        colorFilter: widget.isSvgAssetColored
            ? null
            : ColorFilter.mode(effectiveIconColor, widget.colorBlendMode),
      );
    } else if (widget.icon != null) {
      iconView = Icon(
        widget.icon,
        size: widget.iconSize,
        color: effectiveIconColor,
      );
    }

    if (widget.haveCircularIcon && widget._type == _ButtonType.iconText) {
      return Container(
        width: widget.circularIconRadius ?? widget.iconSize + 12,
        height: widget.circularIconRadius ?? widget.iconSize + 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.circularIconColor ?? Colors.white.withOpacity(0.2),
        ),
        alignment: Alignment.center,
        child: iconView,
      );
    }

    return iconView;
  }
}
