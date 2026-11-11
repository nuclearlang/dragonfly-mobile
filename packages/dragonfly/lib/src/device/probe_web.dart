import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

@JS('__dragonflyTextLayer')
external set _textLayer(JSFunction value);

/// Debug builds only: `globalThis.__dragonflyTextLayer()` gives the texts on the screen with their exact place
/// (logical pixels), color and weight, as JSON. The Dragonfly Terminal device writes them as letters over the
/// picture of the screen, so they read at any terminal size.
void installDeviceProbe() {
  if (!kDebugMode) return;
  _textLayer = (() => jsonEncode(textLayer())).toJS;
}

/// One entry per visible line of text: `t` text, `x y w h` box, `c` color (0xRRGGBB), `b` bold.
List<Map<String, Object>> textLayer() {
  final runs = <Map<String, Object>>[];
  for (final view in RendererBinding.instance.renderViews) {
    final screen = Offset.zero & view.size;
    void visit(RenderObject o) {
      if (o is RenderParagraph) _add(o, screen, runs, view.flutterView.viewId);
      o.visitChildren(visit);
    }

    view.visitChildren(visit);
  }
  return runs;
}

void _add(RenderParagraph p, Rect screen, List<Map<String, Object>> runs, int viewId) {
  if (!p.attached || !p.hasSize) return;
  final clip = _visible(p, screen);
  if (clip == null) return;
  final text = p.text.toPlainText(includeSemanticsLabels: false);
  // icons are text too, in a private-use font: they stay as pixels
  if (text.trim().isEmpty || text.runes.every((r) => r >= 0xE000 && r <= 0xF8FF || r < 0x21)) return;
  final style = _style(p.text);
  final bold = (style?.fontWeight?.value ?? 400) >= 600;
  final color = style?.color;
  // the boxes of the whole text, one or more per line (spans, bidi): joined by line
  final lines = <Rect>[];
  for (final b in p.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: text.length))) {
    final r = b.toRect();
    final i = lines.indexWhere((l) => (l.center.dy - r.center.dy).abs() < r.height / 2);
    if (i < 0) {
      lines.add(r);
    } else {
      lines[i] = lines[i].expandToInclude(r);
    }
  }
  for (final r in lines) {
    final start = p.getPositionForOffset(Offset(r.left + 0.5, r.center.dy)).offset.clamp(0, text.length);
    final end = p.getPositionForOffset(Offset(r.right, r.center.dy)).offset.clamp(start, text.length);
    final line = text.substring(start, end).replaceAll('\n', '').trimRight();
    if (line.isEmpty) continue;
    final box = p.localToGlobal(r.topLeft) & r.size;
    if (!clip.contains(box.center) || !_onTop(p, box.center, viewId)) continue;
    runs.add({
      't': line,
      'x': box.left,
      'y': box.top,
      'w': box.width,
      'h': box.height,
      if (color != null) 'c': color.toARGB32() & 0xFFFFFF,
      'b': bold,
    });
  }
}

/// A finger on the text's middle reaches it: nothing covers it (the page under the current route stays in the
/// tree without being painted; a dialog's barrier covers the page behind).
bool _onTop(RenderParagraph p, Offset at, int viewId) {
  final result = HitTestResult();
  RendererBinding.instance.hitTestInView(result, at, viewId);
  return result.path.any((e) => identical(e.target, p));
}

/// The part of the screen where [p] can be seen: inside every scrolling viewport above it; null when an
/// ancestor hides it (offstage, transparent, a hidden page of an IndexedStack).
Rect? _visible(RenderObject p, Rect screen) {
  var clip = screen;
  RenderObject child = p;
  var parent = p.parent;
  while (parent != null) {
    if (parent is RenderOffstage && parent.offstage) return null;
    if (parent is RenderOpacity && parent.opacity == 0) return null;
    if (parent is RenderAnimatedOpacity && parent.opacity.value == 0) return null;
    if (parent is RenderIndexedStack && !_isIndexed(parent, child)) return null;
    if (parent case final RenderBox box when box is RenderAbstractViewport && box.hasSize) {
      clip = clip.intersect(box.localToGlobal(Offset.zero) & box.size);
    }
    child = parent;
    parent = parent.parent;
  }
  return clip;
}

bool _isIndexed(RenderIndexedStack stack, RenderObject child) {
  var i = 0;
  for (var c = stack.firstChild; c != null; c = stack.childAfter(c), i++) {
    if (identical(c, child)) return i == stack.index;
  }
  return true;
}

/// The style that colors the text: the root span's, or the first child span with a color.
TextStyle? _style(InlineSpan span) {
  TextStyle? found = span.style;
  if (found?.color != null) return found;
  span.visitChildren((s) {
    if (s.style?.color != null) {
      found = s.style!.merge(found);
      return false;
    }
    return true;
  });
  return found;
}
