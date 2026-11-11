import 'package:flutter/widgets.dart';

import '../log/log.dart';
import 'router.dart';

/// The first screen of the app. It shows [child] for at least [minDuration] while [onLoad] prepares the
/// app (ask the backend, fill the local database) and then goes to [next] with the router; when
/// [onLoad] takes longer, it waits for it. It costs one timer and one future: no polling, no frames of
/// its own.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.next,
    required this.child,
    this.minDuration = const Duration(seconds: 3),
    this.onLoad,
    this.onError,
  });

  /// The screen shown after the splash (it needs `@screen(route = ...)`); it replaces the splash, so
  /// "back" does not return to it.
  final Widget next;

  /// What the splash shows (a logo, a progress indicator).
  final Widget child;

  final Duration minDuration;

  /// Runs while the splash is visible.
  final Future<void> Function()? onLoad;

  /// What to show when [onLoad] fails; [retry] runs it again. Without it the error is logged and the
  /// app goes to [next].
  final Widget Function(BuildContext context, Object error, VoidCallback retry)? onError;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    _run(widget.minDuration);
  }

  Future<void> _run(Duration wait) async {
    try {
      // waits for both even when onLoad fails first, so the minimum time always holds
      await Future.wait([Future<void>.delayed(wait), if (widget.onLoad case final load?) load()]);
    } on Object catch (e, stackTrace) {
      Log.e('onLoad failed', error: e, stackTrace: stackTrace, at: 'dragonfly › splash');
      if (widget.onError != null) {
        if (mounted) setState(() => _error = e);
        return;
      }
    }
    if (mounted) context.goTo(widget.next);
  }

  void _retry() {
    setState(() => _error = null);
    _run(Duration.zero);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return error == null ? widget.child : widget.onError!(context, error, _retry);
  }
}
