import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:idara_tracking_app/core/extension/extension.dart';
import 'package:idara_tracking_app/core/widgets/widgets.dart';

class CustomTextFormField extends StatefulWidget {
  const CustomTextFormField({
    super.key,
    this.controller,
    this.isEnabled = true,
    this.haveCountryKey = true,
    this.haveBorder = true,
    this.isFilled = false,
    this.hasValidator = true,
    this.isSecured = false,
    this.validateText = '',
    this.onChange,
    this.onEditingComplete,
    this.isLtr = false,
    this.keyboardType,
    this.prefixIcon,
    this.hintText,
    this.titleWidget,
    this.radius = 6,
    this.borderColor = Colors.grey,
    this.contentPadding,
    this.height,
    this.width,
    this.labelText,
    this.textSize,
    this.suffixIcon,
    this.suffix,
    this.padding,
    this.onTap,
    this.isMultiLine = false,
    this.suffixTap,
    this.focusNode,
    this.onFieldSubmitted,
    this.prefixTap,
    this.maxLines,
    this.textColor,
    this.labelColor,
    this.textFontWeight,
    this.backgroundColor,
    this.suffixIconSize,
    this.suffixIconColor,
    this.hintColor,
    this.shadowColor,
    this.haveShadow = false,
    this.isCollapsed = false,
    this.hintFontSize,
    this.hintFontWeight,
    this.labelTextSize,
    this.labelTextWeight,
    this.prefixWidget,
    this.textAlign,
    this.suffixIconConstraints,
    this.initialValue,
    this.maxLength,
    this.errorMessage,
    this.validator,
    this.autoCorrect = true,
    this.autoFocus = false,
    this.enableSuggestions = true,
    this.textInputAction,
    this.autofillHints,
    this.cursorColor,
    this.dismissOutSideTap = true,
  });

  final Color borderColor;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? padding;
  final TextEditingController? controller;
  final bool hasValidator;
  final bool haveCountryKey;
  final bool haveBorder;
  final double? suffixIconSize;
  final Color? suffixIconColor;
  final double? height;
  final double? width;
  final String? hintText;
  final String? labelText;
  final bool isEnabled;
  final bool isFilled;
  final bool isMultiLine;
  final int? maxLines;
  final bool isLtr;
  final bool isSecured;
  final bool isCollapsed;
  final TextInputType? keyboardType;
  final ValueChanged<String?>? onChange;
  final ValueChanged<String?>? onFieldSubmitted;
  final IconData? prefixIcon;
  final Widget? prefixWidget;
  final IconData? suffixIcon;
  final VoidCallback? suffixTap;
  final VoidCallback? prefixTap;
  final VoidCallback? onTap;
  final VoidCallback? onEditingComplete;
  final double radius;
  final Widget? titleWidget;
  final Widget? suffix;
  final String validateText;
  final double? textSize;
  final FocusNode? focusNode;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? labelColor;
  final Color? hintColor;
  final bool haveShadow;
  final Color? shadowColor;
  final FontWeight? textFontWeight;
  final double? hintFontSize;
  final FontWeight? hintFontWeight;
  final double? labelTextSize;
  final BoxConstraints? suffixIconConstraints;
  final FontWeight? labelTextWeight;
  final TextAlign? textAlign;
  final String? initialValue;
  final int? maxLength;
  final String? errorMessage;

  /// Replaces the built-in validation chain entirely.
  ///
  /// The default chain infers rules from [validateText] and [isSecured] —
  /// notably, [isSecured] enforces password *strength*. That is right when
  /// choosing a password and wrong when entering an existing one: a login
  /// screen must accept whatever the account already has, or a user whose
  /// password predates the rule can never sign in.
  ///
  /// Pass a validator here to opt out of the chain.
  final FormFieldValidator<String>? validator;
  final bool autoCorrect;
  final bool autoFocus;
  final bool enableSuggestions;
  final TextInputAction? textInputAction;

  /// Lets the OS password manager recognise the field.
  ///
  /// Without this a login form cannot be autofilled or saved, which pushes
  /// users towards weaker, memorable passwords.
  final Iterable<String>? autofillHints;
  final Color? cursorColor;
  final bool dismissOutSideTap;

  @override
  State<CustomTextFormField> createState() => _CustomTextFormFieldState();
}

class _CustomTextFormFieldState extends State<CustomTextFormField> {
  bool _isObscure = false;
  int charLength = 0;

  void _updateCharLength(String value) {
    setState(() {
      charLength = value.length;
    });
  }

  @override
  void didChangeDependencies() {
    _isObscure = widget.isSecured;
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.titleWidget != null) widget.titleWidget!,
          if (widget.titleWidget != null) const SizedBox(height: 8),
          ShadowWidget(
            offset: Offset.zero,
            color: !widget.haveShadow
                ? Colors.transparent
                : (widget.shadowColor ?? Theme.of(context).colorScheme.shadow),
            child: GestureDetector(
              onTap: widget.onTap,
              child: SizedBox(
                height: widget.height,
                width: widget.width,
                child: Center(
                  child: TextFormField(
                    controller: widget.controller,
                    initialValue: widget.initialValue,
                    onTap: widget.onTap,
                    onEditingComplete: widget.onEditingComplete,
                    focusNode: widget.focusNode,
                    textAlign: widget.textAlign ?? TextAlign.start,
                    textAlignVertical: TextAlignVertical.center,
                    onTapOutside: (event) {
                      if (!widget.dismissOutSideTap) return;
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        widget.validateText.toLowerCase().contains('phone')
                            ? 9
                            : null,
                      ),
                      if (widget.validateText.toLowerCase().contains('phone') ||
                          widget.keyboardType == TextInputType.number)
                        FilteringTextInputFormatter.digitsOnly,
                    ],
                    textDirection: widget.isLtr ? TextDirection.ltr : null,
                    keyboardType: widget.keyboardType,
                    maxLines: widget.isMultiLine ? widget.maxLines : 1,
                    maxLength: widget.maxLength,
                    autocorrect: widget.autoCorrect,
                    autofocus: widget.autoFocus,
                    enableSuggestions: widget.enableSuggestions,
                    textInputAction: widget.textInputAction,
                    autofillHints: widget.autofillHints,
                    cursorColor: widget.cursorColor,
                    decoration: InputDecoration(
                      isDense: true,
                      errorMaxLines: 3,
                      isCollapsed: widget.isCollapsed,
                      counterText: widget.maxLength != null
                          ? '$charLength / ${widget.maxLength}'
                          : null,
                      hintText: widget.hintText,
                      suffixIconConstraints: widget.suffixIconConstraints,
                      hintStyle: Theme.of(context).textTheme.titleMedium!
                          .copyWith(
                            color:
                                widget.hintColor ??
                                Theme.of(context).colorScheme.primary,
                            fontSize: widget.hintFontSize,
                            fontWeight: widget.hintFontWeight,
                          ),
                      labelText: widget.labelText,
                      alignLabelWithHint: true,
                      labelStyle: TextStyle(
                        color:
                            widget.labelColor ??
                            Theme.of(context).colorScheme.primary,
                        fontSize: widget.labelTextSize,
                        fontWeight: widget.labelTextWeight,
                      ),
                      prefixText:
                          widget.validateText.toLowerCase().contains('phone') &&
                              widget.haveCountryKey
                          ? '+962 '
                          : null,
                      prefixStyle: Theme.of(context).textTheme.labelMedium,
                      suffixStyle: Theme.of(context).textTheme.labelMedium,
                      fillColor:
                          widget.backgroundColor ??
                          (!widget.isEnabled ? Colors.grey : Colors.white70),
                      enabled: widget.isEnabled,
                      filled: widget.backgroundColor != null || widget.isFilled,
                      suffixIcon:
                          widget.suffix ??
                          (widget.isSecured
                              ? IconButton(
                                  icon: Icon(
                                    !_isObscure
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: !_isObscure
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey,
                                  ),
                                  onPressed: () =>
                                      setState(() => _isObscure = !_isObscure),
                                )
                              : widget.suffixIcon != null
                              ? GestureDetector(
                                  onTap: widget.suffixTap,
                                  child: Icon(
                                    widget.suffixIcon,
                                    size: widget.suffixIconSize,
                                    color:
                                        widget.suffixIconColor ??
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                )
                              : null),
                      prefixIcon:
                          widget.prefixWidget ??
                          (widget.prefixIcon != null
                              ? Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: IconButton(
                                    icon: Icon(
                                      widget.prefixIcon,
                                      color: Colors.grey,
                                    ),
                                    onPressed: widget.prefixTap,
                                  ),
                                )
                              : null),
                      border: !widget.haveBorder
                          ? InputBorder.none
                          : OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(widget.radius),
                              ),
                            ),
                      focusedBorder: !widget.haveBorder
                          ? InputBorder.none
                          : OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(widget.radius),
                              ),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                      enabledBorder: !widget.haveBorder
                          ? InputBorder.none
                          : OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(widget.radius),
                              ),
                              borderSide: BorderSide(color: widget.borderColor),
                            ),
                      disabledBorder: !widget.haveBorder
                          ? InputBorder.none
                          : OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(widget.radius),
                              ),
                              borderSide: BorderSide(color: widget.borderColor),
                            ),
                      errorBorder: !widget.haveBorder
                          ? InputBorder.none
                          : OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(widget.radius),
                              ),
                              borderSide: const BorderSide(color: Colors.red),
                            ),
                      contentPadding: widget.contentPadding,
                    ),
                    obscureText: _isObscure,
                    onChanged: (value) {
                      if (widget.onChange != null) widget.onChange!(value);
                      if (widget.maxLength != null) _updateCharLength(value);
                    },
                    style: TextStyle(
                      fontSize: widget.textSize,
                      fontWeight: widget.textFontWeight,
                      color:
                          widget.textColor ??
                          Theme.of(context).colorScheme.primary,
                    ),
                    onFieldSubmitted: widget.onFieldSubmitted,
                    validator:
                        widget.validator ??
                        (value) {
                          if (value!.isEmpty && widget.hasValidator) {
                            return widget.errorMessage ?? 'Required Field';
                          }
                          if (widget.validateText.toLowerCase().contains(
                                'phone',
                              ) &&
                              value.length != 9) {
                            return widget.errorMessage ??
                                'Please Enter Valid Number';
                          }
                          if ((widget.validateText.toLowerCase().contains(
                                    'password',
                                  ) ||
                                  widget.isSecured) &&
                              (value.isPasswordEasy())) {
                            return widget.errorMessage ??
                                'Password not valid at least 8 characters, 1 letter and 1 number and no space';
                          }
                          if (widget.validateText.toLowerCase().contains(
                                'name',
                              ) &&
                              (!value.isFullNameEn())) {
                            return widget.errorMessage ?? 'Valid User Name';
                          }
                          if (value.isNotEmpty &&
                              widget.validateText.toLowerCase().contains(
                                'email',
                              ) &&
                              !value.isEmail()) {
                            return widget.errorMessage ?? 'Valid Not Email';
                          }
                          return null;
                        },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
