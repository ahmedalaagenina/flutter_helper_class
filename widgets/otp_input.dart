import 'package:flutter/material.dart';
import 'package:idara_esign/config/theme/theme.dart';
import 'package:pinput/pinput.dart';

class OtpInput extends StatelessWidget {
  const OtpInput({
    super.key,
    this.length = 6,
    this.onCompleted,
    this.controller,
    this.focusNode,
    this.hasError = false,
  });

  final int length;
  final void Function(String code)? onCompleted;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool hasError;

  // Preferred cell metrics; cells shrink below these when width is tight so the
  // boxes never overflow or look cramped (e.g. inside narrow dialogs).
  static const double _maxCellWidth = 58;
  static const double _maxCellHeight = 56;
  static const double _minCellWidth = 40;

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.primaryContainer;
    const focusedBorderColor = AppColors.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Spacing scales gently with cell size so tight layouts stay balanced.
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _maxCellWidth * length + 14 * (length - 1);
        const separator = 12.0;
        final rawWidth = (available - separator * (length - 1)) / length;
        final double cellWidth = rawWidth
            .clamp(_minCellWidth, _maxCellWidth)
            .toDouble();
        final cellHeight = cellWidth * (_maxCellHeight / _maxCellWidth);

        final basePinTheme = PinTheme(
          width: cellWidth,
          height: cellHeight,
          textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(cellWidth * 0.28),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: const [
              BoxShadow(
                blurRadius: 10,
                offset: Offset(0, 4),
                color: Color(0x14000000),
              ),
            ],
          ),
        );

        final errorPinTheme = basePinTheme.copyWith(
          decoration: basePinTheme.decoration!.copyWith(
            border: Border.all(color: Colors.redAccent, width: 2),
          ),
        );

        return Directionality(
          textDirection: TextDirection.ltr,
          child: Pinput(
            length: length,
            controller: controller,
            focusNode: focusNode,
            mainAxisAlignment: MainAxisAlignment.center,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            forceErrorState: hasError,
            defaultPinTheme: basePinTheme,
            separatorBuilder: (_) => const SizedBox(width: separator),
            focusedPinTheme: basePinTheme.copyWith(
              decoration: basePinTheme.decoration!.copyWith(
                border: Border.all(color: focusedBorderColor, width: 2),
              ),
            ),
            submittedPinTheme: basePinTheme,
            errorPinTheme: errorPinTheme,
            onCompleted: onCompleted,
            onChanged: (_) {},
          ),
        );
      },
    );
  }
}
