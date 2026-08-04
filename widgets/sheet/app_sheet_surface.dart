import 'package:flutter/material.dart';

/// The card a bottom sheet is drawn on.
///
/// Shared so the sheets that swap places over the map — the fleet list and a
/// single device's detail — are literally the same surface. Two hand-rolled
/// copies would drift in radius or shadow, and the swap would then read as one
/// panel being replaced by another rather than as one panel changing contents.
class AppSheetSurface extends StatelessWidget {
  const AppSheetSurface({required this.child, super.key});

  final Widget child;

  static const BorderRadiusGeometry _radius = BorderRadiusDirectional.vertical(
    top: Radius.circular(24),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: _radius,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: _radius, child: child),
    );
  }
}

/// The pill at the top of a sheet that says "this can be dragged".
class AppSheetGrabHandle extends StatelessWidget {
  const AppSheetGrabHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
