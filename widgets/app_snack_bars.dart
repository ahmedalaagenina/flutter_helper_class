import 'package:flutter/material.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class Tone {
  final Color bg;
  final Color fg;
  const Tone({required this.bg, required this.fg});
}

extension SnackbarThemeContext on BuildContext {
  Tone get successTone {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return Tone(
      bg: isDark ? const Color(0xFF032A1C) : const Color(0xFFE2F4EB),
      fg: isDark ? const Color(0xFF2ECA80) : const Color(0xFF0A8043),
    );
  }

  Tone get errorTone {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return Tone(
      bg: isDark ? const Color(0xFF3B0B0B) : const Color(0xFFFEECEB),
      fg: isDark ? const Color(0xFFF35F5F) : const Color(0xFFC5221F),
    );
  }

  Tone get warningTone {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return Tone(
      bg: isDark ? const Color(0xFF332701) : const Color(0xFFFEF3DE),
      fg: isDark ? const Color(0xFFE6AE15) : const Color(0xFFEA8600),
    );
  }

  Tone get infoTone {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return Tone(
      bg: isDark ? const Color(0xFF082645) : const Color(0xFFE8F0FE),
      fg: isDark ? const Color(0xFF3F8CFF) : const Color(0xFF1A73E8),
    );
  }
}

class AppSnackBars {
  static void success(
    String message, {
    BuildContext? context,
    String? actionLabel,
    VoidCallback? onAction,
    SnackBarBehavior? behavior,
    double? elevation,
  }) {
    final effectiveMessenger = _getMessenger(context);
    if (effectiveMessenger == null) return;

    final themeContext = _getThemeContext(context);
    if (themeContext == null) return;

    _show(
      effectiveMessenger,
      tone: themeContext.successTone,
      message: message,
      icon: Icons.check_circle_outline,
      actionLabel: actionLabel,
      onAction: onAction,
      behavior: behavior,
      elevation: elevation,
    );
  }

  static void error(
    String message, {
    BuildContext? context,
    String? actionLabel,
    VoidCallback? onAction,
    SnackBarBehavior? behavior,
    double? elevation,
  }) {
    final effectiveMessenger = _getMessenger(context);
    if (effectiveMessenger == null) return;

    final themeContext = _getThemeContext(context);
    if (themeContext == null) return;

    _show(
      effectiveMessenger,
      tone: themeContext.errorTone,
      message: message,
      icon: Icons.error_outline,
      actionLabel: actionLabel,
      onAction: onAction,
      behavior: behavior,
      elevation: elevation,
    );
  }

  static void warning(
    String message, {
    BuildContext? context,
    String? actionLabel,
    VoidCallback? onAction,
    SnackBarBehavior? behavior,
    double? elevation,
  }) {
    final effectiveMessenger = _getMessenger(context);
    if (effectiveMessenger == null) return;

    final themeContext = _getThemeContext(context);
    if (themeContext == null) return;

    _show(
      effectiveMessenger,
      tone: themeContext.warningTone,
      message: message,
      icon: Icons.warning_amber_rounded,
      actionLabel: actionLabel,
      onAction: onAction,
      behavior: behavior,
      elevation: elevation,
    );
  }

  static void info(
    String message, {
    BuildContext? context,
    String? actionLabel,
    VoidCallback? onAction,
    SnackBarBehavior? behavior,
    double? elevation,
  }) {
    final effectiveMessenger = _getMessenger(context);
    if (effectiveMessenger == null) return;

    final themeContext = _getThemeContext(context);
    if (themeContext == null) return;

    _show(
      effectiveMessenger,
      tone: themeContext.infoTone,
      message: message,
      icon: Icons.info_outline,
      actionLabel: actionLabel,
      onAction: onAction,
      behavior: behavior,
      elevation: elevation,
    );
  }

  static void custom({
    BuildContext? context,
    required Tone tone,
    required String message,
    IconData icon = Icons.notifications_none,
    String? actionLabel,
    VoidCallback? onAction,
    SnackBarBehavior? behavior,
    double? elevation,
  }) {
    final effectiveMessenger = _getMessenger(context);
    if (effectiveMessenger == null) return;

    _show(
      effectiveMessenger,
      tone: tone,
      message: message,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      behavior: behavior,
      elevation: elevation,
    );
  }

  static ScaffoldMessengerState? _getMessenger(BuildContext? context) {
    final fromContext = context != null
        ? ScaffoldMessenger.maybeOf(context)
        : null;
    return fromContext ?? rootScaffoldMessengerKey.currentState;
  }

  static BuildContext? _getThemeContext(BuildContext? context) {
    if (context != null) return context;
    final rootState = rootScaffoldMessengerKey.currentState;
    if (rootState == null) return null;
    return rootState.context;
  }

  static void _show(
    ScaffoldMessengerState messenger, {
    required Tone tone,
    required String message,
    required IconData icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
    SnackBarBehavior? behavior,
    double? elevation,
  }) {
    final bg = tone.bg;
    final fg = tone.fg;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        messenger.clearSnackBars();

        messenger.showSnackBar(
          SnackBar(
            behavior: behavior,
            elevation: elevation,
            duration: duration,
            backgroundColor: Colors.transparent,
            padding: EdgeInsets.zero,
            content: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth < 520
                    ? constraints.maxWidth - 32
                    : 480.0;

                return Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: _SnackContent(
                      bg: bg,
                      fg: fg,
                      message: message,
                      icon: icon,
                      actionLabel: actionLabel,
                      onAction: onAction,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      } catch (_) {}
    });
  }

  static void showUndo({
    required String message,
    required VoidCallback onUndo,
    BuildContext? context,
    Duration duration = const Duration(seconds: 5),
  }) {
    final effectiveMessenger = _getMessenger(context);
    if (effectiveMessenger == null) return;

    final themeContext = _getThemeContext(context);
    if (themeContext == null) return;

    // We can use infoTone or successTone for undo actions, infoTone generally looks best:
    final tone = themeContext.infoTone;

    final bg = tone.bg;
    final fg = tone.fg;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        effectiveMessenger.clearSnackBars();

        effectiveMessenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            elevation: 0,
            duration: duration,
            backgroundColor: Colors.transparent,
            padding: EdgeInsets.zero,
            content: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth < 520
                    ? constraints.maxWidth - 32
                    : 480.0;

                return Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: _UndoSnackContent(
                      bg: bg,
                      fg: fg,
                      message: message,
                      onUndo: onUndo,
                      duration: duration,
                      messenger: effectiveMessenger,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      } catch (_) {}
    });
  }
}

class _UndoSnackContent extends StatelessWidget {
  final Color bg;
  final Color fg;
  final String message;
  final VoidCallback onUndo;
  final Duration duration;
  final ScaffoldMessengerState messenger;

  const _UndoSnackContent({
    required this.bg,
    required this.fg,
    required this.message,
    required this.onUndo,
    required this.duration,
    required this.messenger,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
            blurRadius: 20,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
          if (isDark)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.05),
              blurRadius: 6,
              spreadRadius: -2,
              offset: const Offset(0, -2),
            ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CountDownWidget(
            duration: duration,
            circularColor: fg,
            counterTextColor: fg,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () {
              messenger.hideCurrentSnackBar();
              onUndo.call();
            },
            style: TextButton.styleFrom(
              foregroundColor: fg,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Undo',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class CountDownWidget extends StatefulWidget {
  const CountDownWidget({
    super.key,
    required this.duration,
    required this.circularColor,
    required this.counterTextColor,
  });

  final Duration duration;
  final Color circularColor;
  final Color counterTextColor;

  @override
  State<CountDownWidget> createState() => _CountDownWidgetState();
}

class _CountDownWidgetState extends State<CountDownWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  String get count {
    Duration count = controller.duration! * controller.value;
    return controller.isDismissed
        ? '0'
        : '${(count.inMilliseconds / 1000).ceil()}';
  }

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: widget.duration);
    controller.reverse(from: 1);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                value: controller.value,
                color: widget.circularColor,
                strokeWidth: 2,
                backgroundColor: widget.circularColor.withValues(alpha: 0.2),
              ),
            ),
            Text(
              count,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: widget.counterTextColor,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SnackContent extends StatelessWidget {
  final Color bg;
  final Color fg;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SnackContent({
    required this.bg,
    required this.fg,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
            blurRadius: 20,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
          if (isDark)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.05),
              blurRadius: 6,
              spreadRadius: -2,
              offset: const Offset(0, -2),
            ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: () {
                // ✅ Safe hide snackbar
                final messenger =
                    ScaffoldMessenger.maybeOf(context) ??
                    rootScaffoldMessengerKey.currentState;
                messenger?.hideCurrentSnackBar();

                onAction!.call();
              },
              style: TextButton.styleFrom(
                foregroundColor: fg,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
