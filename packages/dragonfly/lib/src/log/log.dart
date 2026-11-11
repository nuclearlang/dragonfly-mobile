import 'dart:convert';

import 'package:flutter/foundation.dart';

/// The levels, with the vivid colors of Bootstrap's alerts in dark mode for the title and the frame (primary,
/// info, success, warning, danger) and a message color that contrasts with them. Colors are xterm-256: the debug consoles of the
/// IDEs show them all (24-bit colors turn gray in some of them).
enum LogLevel {
  debug('DEBUG', 75, 255),
  info('INFO', 51, 255),
  success('SUCCESS', 42, 255),
  warn('WARNING', 220, 230),
  error('ERROR', 203, 224);

  const LogLevel(this.label, this.color, this.text);

  final String label;

  /// Color of the title and of the frame (xterm-256).
  final int color;

  /// Color of the message: near white, with a light tint in warnings and errors (xterm-256).
  final int text;
}

/// Vivid colors (xterm-256) for the component of each breadcrumb, readable on the dark background of the
/// IDE consoles. Purple is reserved for Dragonfly's own logs ([Log.dragonflyColor]).
enum LogColor {
  mint(79),
  sky(117),
  peach(215),
  lemon(227),
  rose(211),
  aqua(80),
  lime(149),
  indigo(105);

  const LogColor(this.color);

  /// xterm-256 color.
  final int color;
}

/// One written log: what [Log.sink] receives.
class LogEntry {
  LogEntry(this.level, this.message, {this.data, this.error, this.stackTrace, this.at, DateTime? time})
    : time = time ?? DateTime.now();

  final LogLevel level;
  final String message;

  /// The data, with sensitive values already masked.
  final Object? data;
  final Object? error;
  final StackTrace? stackTrace;

  /// Where the log was written: `characters › repository › CharacterRepository.getPage · <file>.nuc:12`
  /// (Nuclear writes it in every `Log` call).
  final String? at;
  final DateTime time;

  /// The breadcrumb, without the location: `[characters, repository, CharacterRepository.getPage]`.
  List<String> get crumbs => at == null ? const [] : at!.split(' · ').first.split(' › ');

  /// The `.nuc` file and line, when known.
  String? get location {
    final parts = at?.split(' · ');
    return parts != null && parts.length > 1 ? parts[1] : null;
  }

  /// The component: the first crumb.
  String? get component => crumbs.firstOrNull;
}

/// App logs, grouped and colored by component:
///
/// ```text
/// ┏━  INFO      characters › repository › CharacterRepository.getPage  12:04:31.120 ━━━━━━━━━━━━━━━
/// ┃  page loaded
/// ┃  data: {"page":2,"token":"***"}
/// ┗━ components/characters/data/character_repository.nuc:12 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/// ```
///
/// In release builds only warnings and errors are written. Values of sensitive keys (`token`, `password`,
/// `authorization`, `secret`, `cookie`) are masked everywhere.
abstract final class Log {
  /// The lowest level written; in release builds it is never below [LogLevel.warn].
  static LogLevel level = LogLevel.debug;

  /// Receives every written entry (send them to a crash reporter, a file...).
  static void Function(LogEntry entry)? sink;

  /// Writes to the console (false: only [sink]).
  static bool console = true;

  /// ANSI colors in the console; false gives plain text (files, terminals without colors).
  static bool colors = true;

  /// Color of each component; one without a color gets one of [LogColor] by its name, always the same.
  /// The `logColor` of a component's config is written here.
  static final Map<String, LogColor> componentColors = {};

  static const sensitive = ['token', 'password', 'authorization', 'secret', 'cookie'];

  /// Debug (blue): details for the developer while building, such as values, steps or requests. Not written
  /// in release builds.
  static void d(String message, {Object? data, String? at}) => write(LogLevel.debug, message, data: data, at: at);

  /// Info (cyan): something normal happened that is worth knowing, such as a screen opening or a session
  /// starting. Not written in release builds.
  static void i(String message, {Object? data, String? at}) => write(LogLevel.info, message, data: data, at: at);

  /// Success (green): an operation finished well, such as data loaded or a form saved. Not written in release
  /// builds.
  static void s(String message, {Object? data, String? at}) => write(LogLevel.success, message, data: data, at: at);

  /// Warning (yellow): something unexpected that the app survives, such as a slow
  /// response, a retry or a missing value with a default. Written in release builds.
  static void w(String message, {Object? data, String? at}) => write(LogLevel.warn, message, data: data, at: at);

  /// Error (red): something failed. Pass [error] and [stackTrace] to see the exception and the exact place
  /// where it happened (marked with ▶, the only line that blinks). Written in release builds.
  static void e(String message, {Object? data, Object? error, StackTrace? stackTrace, String? at}) =>
      write(LogLevel.error, message, data: data, error: error, stackTrace: stackTrace, at: at);

  /// Same as [d].
  static void debug(String message, {Object? data, String? at}) => d(message, data: data, at: at);

  /// Same as [i].
  static void info(String message, {Object? data, String? at}) => i(message, data: data, at: at);

  /// Same as [s].
  static void success(String message, {Object? data, String? at}) => s(message, data: data, at: at);

  /// Same as [w].
  static void warn(String message, {Object? data, String? at}) => w(message, data: data, at: at);

  /// Same as [e].
  static void error(String message, {Object? data, Object? error, StackTrace? stackTrace, String? at}) =>
      e(message, data: data, error: error, stackTrace: stackTrace, at: at);

  /// Writes a log of level [l]; [d], [i], [s], [w] and [e] call it. [data] is any value (shown as JSON,
  /// sensitive keys masked); [at] is the breadcrumb, written by Nuclear.
  static void write(LogLevel l, String message, {Object? data, Object? error, StackTrace? stackTrace, String? at}) {
    final min = kReleaseMode && level.index < LogLevel.warn.index ? LogLevel.warn : level;
    if (l.index < min.index) return;
    final entry = LogEntry(l, message, data: mask(data), error: error, stackTrace: stackTrace, at: at);
    sink?.call(entry);
    // an empty line between blocks
    if (console) debugPrint('\n${format(entry, colors: colors)}');
  }

  /// The color of [component]'s breadcrumb.
  static LogColor colorOf(String component) {
    final chosen = componentColors[component];
    if (chosen != null) return chosen;
    // a stable hash: String.hashCode may change between runs
    var h = 0;
    for (final c in component.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return LogColor.values[h % LogColor.values.length];
  }

  /// Color of the logs of Dragonfly itself (`dragonfly › http`...).
  static const dragonflyColor = 141;

  /// Width of the frame's top and bottom lines.
  static const width = 96;

  // colors of code (VS Code Dark+): kinds, classes, methods, keys, strings, numbers, literals, comments
  static const _kind = 74, _class = 79, _method = 187, _key = 117;
  static const _string = 180, _number = 151, _gray = 245;

  /// The text of [entry] as the console shows it. Bold, blink and color go in separate sequences: the debug
  /// console of VS Code reads `ESC[1;38;5;42m` as bold + blink (5) + background (42).
  static String format(LogEntry entry, {bool colors = false}) {
    String paint(String text, int c, {bool bold = false, bool blink = false}) =>
        colors ? '${bold ? '\x1B[1m' : ''}${blink ? '\x1B[5m' : ''}\x1B[38;5;${c}m$text\x1B[0m' : text;
    final lv = entry.level;
    String frame(String text) => paint(text, lv.color, bold: true);
    final label = ' ${lv.label.padRight(7)} ';
    final badge = paint(label, lv.color, bold: true);

    final t = entry.time;
    String two(int n) => '$n'.padLeft(2, '0');
    final time = '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.${'${t.millisecond}'.padLeft(3, '0')}';

    // header: ┏━ BADGE  component › kind › Class.method  time ━━━━
    final crumbs = entry.crumbs;
    final head = StringBuffer();
    var plain = 3 + label.length;
    if (crumbs.isNotEmpty) {
      final c = entry.component == 'dragonfly' ? dragonflyColor : colorOf(entry.component!).color;
      head.write('  ${paint(crumbs.first, c, bold: true)}');
      plain += 2 + crumbs.first.length;
      for (final (i, crumb) in crumbs.skip(1).indexed) {
        head.write(paint(' › ', _gray));
        final last = i == crumbs.length - 2;
        final dot = crumb.indexOf('.');
        if (last && dot > 0) {
          head
            ..write(paint(crumb.substring(0, dot), _class))
            ..write(paint(crumb.substring(dot), _method));
        } else {
          head.write(paint(crumb, last && crumbs.length > 2 ? _class : _kind));
        }
        plain += 3 + crumb.length;
      }
    }
    head.write('  ${paint(time, _gray)} ');
    plain += 3 + time.length;
    final out = StringBuffer()
      ..write(frame('┏━ '))
      ..write(badge)
      ..write(head)
      ..write(frame('━' * (width - plain).clamp(3, width)));

    final bar = frame('┃');
    void line(String text) => out.write('\n$bar  $text');
    for (final l in entry.message.split('\n')) {
      line(paint(l, lv.text));
    }
    if (entry.data != null) line('${paint('data:', _gray)} ${_json(entry.data, colors ? paint : null)}');
    if (entry.error != null) line('${frame('error:')} ${paint('${entry.error}', lv.text, bold: true)}');
    if (entry.stackTrace != null) {
      final frames = entry.stackTrace.toString().trimRight().split('\n').take(10).toList();
      // the exact place: the first frame of the app, not of Dart, Flutter or Dragonfly
      final at = frames.indexWhere((f) => !RegExp(r'\((dart:|package:(flutter|dragonfly|stack_trace)/)').hasMatch(f));
      for (final (i, f) in frames.indexed) {
        line(i == at ? paint('▶ ${f.trim()}', LogLevel.error.color, bold: true, blink: true) : paint(f, _gray));
      }
    }
    final loc = entry.location;
    final foot = loc == null ? '' : ' ${paint(loc, _gray)} ';
    out.write('\n${frame('┗━')}$foot${frame('━' * (width - 2 - (loc == null ? 0 : loc.length + 2)).clamp(3, width))}');
    return out.toString();
  }

  /// [data] as JSON, colored like code when [paint] is given.
  static String _json(Object? data, String Function(String, int)? paint) {
    String text;
    try {
      text = jsonEncode(data);
    } catch (_) {
      return '$data';
    }
    if (paint == null) return text;
    return text.replaceAllMapped(
      RegExp(r'("(?:\\.|[^"\\])*")(\s*:)?|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null'),
      (m) {
        if (m[1] != null) return m[2] != null ? '${paint(m[1]!, _key)}${m[2]}' : paint(m[1]!, _string);
        final t = m[0]!;
        return paint(t, t[0] == '-' || (t.codeUnitAt(0) ^ 0x30) <= 9 ? _number : _kind);
      },
    );
  }

  /// The app's package: its frames lead the stack of an exception (`startDragonfly` sets it).
  static String? appPackage;

  static final Set<String> _shownErrors = {};

  /// Flutter's errors (build, layout, platform messages...) printed by [formatError] instead of Flutter's
  /// own format, and sent to [sink].
  static void catchFlutterErrors({String? app}) {
    appPackage = app ?? appPackage;
    FlutterError.presentError = presentError;
  }

  /// What [FlutterError.presentError] does with [catchFlutterErrors]: the whole report the first time, one
  /// line when the same error repeats (a layout overflow repeats on every frame).
  static void presentError(FlutterErrorDetails details) {
    if (details.silent && !kDebugMode) return;
    sink?.call(
      LogEntry(
        LogLevel.error,
        details.exceptionAsString(),
        error: details.exception,
        stackTrace: details.stack,
        at: 'flutter › ${details.library ?? 'error'}',
      ),
    );
    if (!console) return;
    final first = _shownErrors.add(details.summary.toString());
    debugPrint(first ? '\n${formatError(details, colors: colors)}' : _again(details, colors));
  }

  static const _danger = 196, _dangerBg = 160, _soft = 224, _hot = 210;

  static String _again(FlutterErrorDetails details, bool colors) {
    final text = '╟─ ✖ again: ${details.summary}';
    return colors ? '\x1B[38;5;${_danger}m$text\x1B[0m' : text;
  }

  /// The text of a Flutter error: what failed, where, and the stack with the app's frames first in sight
  /// (Dart SDK frames hidden, Flutter's dimmed).
  static String formatError(FlutterErrorDetails details, {bool colors = false}) {
    String paint(String text, int c, {bool bold = false, bool blink = false}) =>
        colors ? '${bold ? '\x1B[1m' : ''}${blink ? '\x1B[5m' : ''}\x1B[38;5;${c}m$text\x1B[0m' : text;
    String frame(String text) => paint(text, _danger, bold: true);
    final bar = frame('║');
    final out = StringBuffer();
    void line([String text = '']) => out.write('\n$bar  $text');
    // long lines wrap under their own indentation
    void wrapped(String text, int color, {bool bold = false, String indent = ''}) {
      final words = text.split(' ');
      var current = indent;
      for (final w in words) {
        if (current.trim().isNotEmpty && current.length + w.length + 1 > width - 4) {
          line(paint(current, color, bold: bold));
          current = '$indent  ';
        }
        current += current.trim().isEmpty ? w : ' $w';
      }
      if (current.trim().isNotEmpty) line(paint(current, color, bold: bold));
    }

    final t = DateTime.now();
    String two(int n) => '$n'.padLeft(2, '0');
    final time = '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
    // a red bar across the whole width, between double lines
    final title = ' ✖  EXCEPTION  ·  ${details.library ?? 'flutter'}  ·  $time'.padRight(width - 3);
    out
      ..write(frame('╔${'═' * (width - 1)}'))
      ..write('\n${frame('║')} ')
      ..write(colors ? '\x1B[1m\x1B[38;5;231m\x1B[48;5;${_dangerBg}m$title\x1B[0m' : title)
      ..write('\n${frame('╠${'═' * (width - 1)}')}');
    line();
    final context = details.context?.toDescription();
    if (context != null && context.isNotEmpty) {
      line(paint(context, _gray));
      line();
    }

    // the message: locations as "at", code (assertions) like code, the rest as text
    final location = RegExp(r'^(file|package|dart|org-dartlang)\S*:\d+(:\d+)?$');
    var firstText = true;
    var gap = false;
    final at = <String>[];
    for (final raw in details.exceptionAsString().trim().split('\n')) {
      final l = raw.trim();
      if (l.isEmpty) continue;
      if (location.hasMatch(l)) {
        at.add(l);
        continue;
      }
      // the title of the error, an empty line, and the rest
      if (!firstText && gap) {
        line();
        gap = false;
      }
      if (RegExp(r'^[\w.!]+ (is!?|==|!=|<|>|<=|>=) |\|\||&&').hasMatch(l) && !l.startsWith('"')) {
        wrapped(l, _method);
      } else {
        wrapped(l.replaceAll(RegExp(r'^"|"$'), ''), firstText ? _hot : _soft, bold: firstText);
        gap = firstText;
        firstText = false;
      }
    }
    if (at.isNotEmpty) line();
    for (final l in at) {
      line('${paint('at', _gray)} ${paint(_short(l), _key)}');
    }

    final info = details.informationCollector?.call().map((n) => n.toString()).where((s) => s.isNotEmpty);
    if (info != null && info.isNotEmpty) {
      line();
      for (final i in info) {
        for (final l in i.split('\n')) {
          wrapped(l, _gray);
        }
      }
    }

    final stack = details.stack;
    if (stack != null) {
      line();
      line(paint('stack', _gray, bold: true));
      final frames = stack.toString().split('\n').map(_Frame.parse).whereType<_Frame>().toList();
      var hidden = 0;
      var shown = 0;
      var marked = false;
      void flushHidden() {
        if (hidden > 0) line(paint('   · $hidden Dart SDK frame${hidden == 1 ? '' : 's'}', _gray));
        hidden = 0;
      }

      for (final f in frames) {
        if (f.sdk) {
          hidden++;
          continue;
        }
        if (shown == 16) break;
        flushHidden();
        shown++;
        final app = appPackage != null ? f.package == appPackage : !f.flutter && f.package != 'dragonfly';
        final where = '${'${f.path}:${f.line}'.padRight(55)} ';
        final pkg = '${(app ? 'app' : f.package).padRight(9)} ';
        if (app) {
          final first = !marked;
          marked = true;
          line(
            '${paint(first ? '▶ ' : '  ', _danger, bold: true, blink: first)}'
            '${paint(pkg, _class, bold: true)}${paint(where, _key, bold: true)}${paint(f.method, _method, bold: true)}',
          );
        } else {
          line('  ${paint(pkg, _gray)}${paint(where, _gray)}${paint(f.method, _gray)}');
        }
      }
      flushHidden();
      final rest = frames.where((f) => !f.sdk).length - shown;
      if (rest > 0) line(paint('   · $rest more', _gray));
    }
    line();
    out.write('\n${frame('╚${'═' * (width - 1)}')}');
    return out.toString();
  }

  /// `file:///…/packages/flutter/lib/src/services/raw_keyboard.dart:863:7` → `flutter/…/raw_keyboard.dart:863:7`.
  static String _short(String uri) {
    final m = RegExp(r'packages/(\w+)/lib/(.+)$').firstMatch(uri);
    if (m != null) return '${m[1]}/${m[2]}';
    return uri.replaceFirst('package:', '');
  }

  /// [data] with the values of sensitive keys replaced by `***`.
  static Object? mask(Object? data) {
    if (data is Map) {
      return {
        for (final e in data.entries)
          e.key: sensitive.any((s) => '${e.key}'.toLowerCase().contains(s)) ? '***' : mask(e.value),
      };
    }
    if (data is List) return data.map(mask).toList();
    return data;
  }
}

/// One line of a stack trace, from the VM (`#3  Foo.bar (package:app/foo.dart:12:5)`) or from the web
/// (`package:app/foo.dart 12:5  bar`).
class _Frame {
  _Frame(this.uri, this.line, this.method);

  final String uri;
  final String line;
  final String method;

  static final _vm = RegExp(r'^#\d+\s+(.+?) \((.+?)(?::(\d+))?(?::\d+)?\)$');
  static final _web = RegExp(r'^(\S+) (\d+)(?::\d+)?\s+(.+)$');

  static _Frame? parse(String raw) {
    final l = raw.trim();
    final vm = _vm.firstMatch(l);
    if (vm != null) return _Frame(vm[2]!, vm[3] ?? '', vm[1]!.replaceAll('.<anonymous closure>', ' <fn>'));
    final web = _web.firstMatch(l);
    if (web != null) return _Frame(web[1]!, web[2]!, web[3]!.trim());
    return null;
  }

  bool get sdk => uri.startsWith('dart:') || uri.startsWith('dart-sdk/') || uri.startsWith('org-dartlang');

  String get package => uri.startsWith('package:') ? uri.substring(8).split('/').first : uri.split('/').first;

  bool get flutter => package == 'flutter' || package == 'flutter_test';

  /// The file inside its package, without `src/`.
  String get path {
    if (!uri.startsWith('package:')) return uri;
    return uri.substring(9 + package.length).replaceFirst('src/', '');
  }
}
