import 'dart:async';

import 'package:flutter/material.dart';

import '../i18n/translations.dart';

/// The kind of message, as in Bootstrap: each one has its color and its icon.
enum PopupType { info, success, warning, danger }

/// The width of a dialog.
enum DialogSize { small, medium, large }

/// How popups look. The colors come from the app's theme (info = primary, danger = error); any color,
/// icon or width can be replaced: `Popups.theme = PopupTheme(colors: {PopupType.success: Colors.teal})`.
class PopupTheme {
  const PopupTheme({
    this.colors = const {},
    this.icons = const {},
    this.radius = 12,
    this.widths = const {DialogSize.small: 320, DialogSize.medium: 520, DialogSize.large: 800},
  });

  final Map<PopupType, Color> colors;
  final Map<PopupType, IconData> icons;
  final double radius;
  final Map<DialogSize, double> widths;

  Color color(BuildContext context, PopupType type) {
    final custom = colors[type];
    if (custom != null) return custom;
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return switch (type) {
      PopupType.info => scheme.primary,
      PopupType.success => dark ? Colors.green.shade300 : Colors.green.shade700,
      PopupType.warning => dark ? Colors.amber.shade300 : Colors.amber.shade900,
      PopupType.danger => scheme.error,
    };
  }

  IconData icon(PopupType type) =>
      icons[type] ??
      switch (type) {
        PopupType.info => Icons.info_outline,
        PopupType.success => Icons.check_circle_outline,
        PopupType.warning => Icons.warning_amber_rounded,
        PopupType.danger => Icons.error_outline,
      };
}

/// A dialog in three parts, like a Bootstrap modal: the header (the icon of its [type], [header] and a
/// close button), the body ([child]) and the footer. The footer appears with [footer], [onAccept] or
/// [onCloseButton]: it has a Close button and, with [onAccept], an Accept button (both localized).
/// [onClose] runs however the dialog closes. With [autoClose] it closes by itself.
///
/// ```dart
/// DragonflyDialog.success(child: Text('Saved')).show(context);
/// final ok = await DragonflyDialog.danger(child: Text('Delete?'), onAccept: () {}).show(context);
/// ```
class DragonflyDialog extends StatefulWidget {
  const DragonflyDialog({
    super.key,
    this.type = PopupType.info,
    required this.child,
    this.header,
    this.footer,
    this.onClose,
    this.onCloseButton,
    this.onAccept,
    this.size = DialogSize.medium,
    this.autoClose,
    this.color,
    this.icon,
  });

  const DragonflyDialog.info({
    super.key,
    required this.child,
    this.header,
    this.footer,
    this.onClose,
    this.onCloseButton,
    this.onAccept,
    this.size = DialogSize.medium,
    this.autoClose,
    this.color,
    this.icon,
  }) : type = PopupType.info;

  const DragonflyDialog.success({
    super.key,
    required this.child,
    this.header,
    this.footer,
    this.onClose,
    this.onCloseButton,
    this.onAccept,
    this.size = DialogSize.medium,
    this.autoClose,
    this.color,
    this.icon,
  }) : type = PopupType.success;

  const DragonflyDialog.warning({
    super.key,
    required this.child,
    this.header,
    this.footer,
    this.onClose,
    this.onCloseButton,
    this.onAccept,
    this.size = DialogSize.medium,
    this.autoClose,
    this.color,
    this.icon,
  }) : type = PopupType.warning;

  const DragonflyDialog.danger({
    super.key,
    required this.child,
    this.header,
    this.footer,
    this.onClose,
    this.onCloseButton,
    this.onAccept,
    this.size = DialogSize.medium,
    this.autoClose,
    this.color,
    this.icon,
  }) : type = PopupType.danger;

  static const small = DialogSize.small;
  static const medium = DialogSize.medium;
  static const large = DialogSize.large;

  final PopupType type;
  final Widget child;
  final Widget? header;
  final Widget? footer;
  final VoidCallback? onClose;
  final VoidCallback? onCloseButton;
  final VoidCallback? onAccept;
  final DialogSize size;
  final Duration? autoClose;

  /// Replace the color and the icon of [type] for this dialog only.
  final Color? color;
  final IconData? icon;

  /// Opens the dialog; true when the user pressed Accept.
  Future<bool> show(BuildContext context, {bool dismissible = true}) async {
    final accepted = await showDialog<bool>(context: context, barrierDismissible: dismissible, builder: (_) => this);
    onClose?.call();
    return accepted ?? false;
  }

  @override
  State<DragonflyDialog> createState() => _DragonflyDialogState();
}

class _DragonflyDialogState extends State<DragonflyDialog> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final after = widget.autoClose;
    if (after != null) _timer = Timer(after, () => mounted ? Navigator.of(context).maybePop(false) : null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final theme = Popups.theme;
    final color = w.color ?? theme.color(context, w.type);
    final nav = Navigator.of(context);
    final hasFooter = w.footer != null || w.onAccept != null || w.onCloseButton != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.radius)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: theme.widths[w.size] ?? 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  Icon(w.icon ?? theme.icon(w.type), color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: Theme.of(context).textTheme.titleMedium,
                      child: w.header ?? const SizedBox.shrink(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'dragonfly.dialog.close'.tr(),
                    icon: const Icon(Icons.close),
                    onPressed: () => nav.pop(false),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 20), child: w.child),
            ),
            if (hasFooter) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(child: w.footer ?? const SizedBox.shrink()),
                    TextButton(
                      onPressed: () {
                        w.onCloseButton?.call();
                        nav.pop(false);
                      },
                      child: Text('dragonfly.dialog.close'.tr()),
                    ),
                    if (w.onAccept != null) ...[
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: _on(color)),
                        onPressed: () {
                          w.onAccept!();
                          nav.pop(true);
                        },
                        child: Text('dragonfly.dialog.accept'.tr()),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Black or white, whichever reads on [background].
Color _on(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark ? Colors.white : Colors.black;

/// Popups with one call: dialogs, toasts and snack bars, all with the [PopupType] colors and icons.
abstract final class Popups {
  static PopupTheme theme = const PopupTheme();

  /// A message with a title and a Close button.
  static Future<void> alert(BuildContext context, String title, String message, {PopupType type = PopupType.info}) =>
      DragonflyDialog(type: type, header: Text(title), onCloseButton: () {}, child: Text(message)).show(context);

  /// true when the user accepts.
  static Future<bool> confirm(
    BuildContext context,
    String title,
    String message, {
    PopupType type = PopupType.warning,
  }) => DragonflyDialog(type: type, header: Text(title), onAccept: () {}, child: Text(message)).show(context);

  /// A dialog with any content.
  static Future<T?> show<T>(BuildContext context, Widget child, {bool dismissible = true}) => showDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    builder: (_) => Dialog(child: child),
  );

  /// A blocking spinner until [task] ends; returns its result.
  static Future<T> loading<T>(BuildContext context, Future<T> task) async {
    final nav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator())),
    );
    try {
      return await task;
    } finally {
      nav.pop();
    }
  }

  /// A short message over the app that does not block it and goes away after [duration]. It needs no
  /// Scaffold.
  static void toast(
    BuildContext context,
    String message, {
    PopupType type = PopupType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final color = theme.color(context, type);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: 16,
        right: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 32,
        child: IgnorePointer(
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 200),
              builder: (_, t, child) => Opacity(opacity: t, child: child),
              child: Material(
                color: color,
                elevation: 6,
                borderRadius: BorderRadius.circular(theme.radius),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: _Line(icon: theme.icon(type), text: message, color: _on(color)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Timer(duration, entry.remove);
  }

  /// A snack bar of the nearest Scaffold, with the color and icon of [type] and an optional action.
  static void snackbar(
    BuildContext context,
    String message, {
    PopupType type = PopupType.info,
    String? action,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final color = theme.color(context, type);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        content: _Line(icon: theme.icon(type), text: message, color: _on(color)),
        action: action == null
            ? null
            : SnackBarAction(label: action, textColor: _on(color), onPressed: onAction ?? () {}),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 12),
      Flexible(
        child: Text(text, style: TextStyle(color: color)),
      ),
    ],
  );
}
