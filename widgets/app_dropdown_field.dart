import 'package:admin_panel_standalone/config/theme/theme.dart';
import 'package:flutter/material.dart';

class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
    this.hint,
  });

  final T value;
  final List<T> items;
  final String Function(T item) labelBuilder;
  final ValueChanged<T> onChanged;

  /// Shown while [value] is null (nothing chosen yet).
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: hint == null ? null : Text(hint!),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(labelBuilder(item)),
                ),
              )
              .toList(),
          onChanged: (selected) {
            if (selected != null) onChanged(selected);
          },
        ),
      ),
    );
  }
}
