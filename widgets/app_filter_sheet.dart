import 'package:flutter/material.dart';
import 'package:idara_driver/config/theme/theme.dart';
import 'package:idara_driver/core/widgets/app_button.dart';

class AppFilterSheetOption<T> {
  const AppFilterSheetOption({
    required this.value,
    required this.label,
    this.selectedIcon = Icons.check_circle_rounded,
    this.unselectedIcon = Icons.radio_button_unchecked_rounded,
  });

  final T value;
  final String label;
  final IconData selectedIcon;
  final IconData unselectedIcon;
}

typedef AppFilterSelectionUpdater<T> =
    Set<T> Function(Set<T> currentSelection, T value);

class AppFilterSheet<T> extends StatefulWidget {
  const AppFilterSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.initialSelection,
    required this.onOptionToggled,
    required this.clearSelection,
    this.clearButtonText = 'Clear',
    this.applyButtonText = 'Apply',
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(28)),
  });

  final String title;
  final String subtitle;
  final List<AppFilterSheetOption<T>> options;
  final List<T> initialSelection;
  final AppFilterSelectionUpdater<T> onOptionToggled;
  final List<T> clearSelection;
  final String clearButtonText;
  final String applyButtonText;
  final BorderRadius borderRadius;

  @override
  State<AppFilterSheet<T>> createState() => _AppFilterSheetState<T>();
}

class _AppFilterSheetState<T> extends State<AppFilterSheet<T>> {
  late Set<T> _selectedValues;

  @override
  void initState() {
    super.initState();
    _selectedValues = widget.initialSelection.toSet();
  }

  List<T> _selectedValuesInOptionOrder() {
    return widget.options
        .map((option) => option.value)
        .where(_selectedValues.contains)
        .toList(growable: false);
  }

  void _toggleOption(T value) {
    setState(() {
      _selectedValues = widget.onOptionToggled(
        Set<T>.from(_selectedValues),
        value,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appTheme.colors;
    final typography = context.appTheme.typography;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: widget.borderRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.title,
              style: typography.headlineSmall.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.subtitle,
              style: typography.bodyMedium.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            ...widget.options.map((option) {
              final isSelected = _selectedValues.contains(option.value);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _toggleOption(option.value),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? colors.primary
                            : colors.outlineVariant,
                        width: isSelected ? 1.5 : 1,
                      ),
                      color: isSelected
                          ? colors.primary.withValues(alpha: 0.08)
                          : colors.surface,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.label,
                            style: typography.titleMedium.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          isSelected
                              ? option.selectedIcon
                              : option.unselectedIcon,
                          color: isSelected
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton.text(
                    title: widget.clearButtonText,
                    backgroundColor: colors.surface,
                    textColor: colors.onSurface,
                    border: Border.all(color: colors.outlineVariant),
                    onPressed: () {
                      Navigator.of(context).pop(widget.clearSelection);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton.text(
                    title: widget.applyButtonText,
                    backgroundColor: colors.primary,
                    textColor: colors.onPrimary,
                    onPressed: () {
                      Navigator.of(context).pop(_selectedValuesInOptionOrder());
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AppActiveFilterItem<T> {
  const AppActiveFilterItem({required this.value, required this.label});

  final T value;
  final String label;
}

class AppActiveFilters<T> extends StatelessWidget {
  const AppActiveFilters({
    super.key,
    required this.selectedFilters,
    required this.onClearFilter,
    required this.onClearAll,
    this.padding = EdgeInsets.zero,
  });

  final List<AppActiveFilterItem<T>> selectedFilters;
  final ValueChanged<T> onClearFilter;
  final VoidCallback onClearAll;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (selectedFilters.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = context.appTheme.colors;
    final typography = context.appTheme.typography;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...selectedFilters.map(
            (filter) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(
                  filter.label,
                  style: typography.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                deleteIcon: const Icon(Icons.close_rounded, size: 18),
                onDeleted: () => onClearFilter(filter.value),
                backgroundColor: colors.surface,
                side: BorderSide(color: colors.outlineVariant),
              ),
            ),
          ),
          AppButton.circleIcon(
            icon: Icons.close_rounded,
            size: 38,
            iconSize: 22,
            backgroundColor: colors.error,
            iconColor: colors.onError,
            onPressed: onClearAll,
          ),
        ],
      ),
    );
  }
}
