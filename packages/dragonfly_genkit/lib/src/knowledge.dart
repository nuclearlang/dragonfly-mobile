import 'dart:math' as math;

import 'package:genkit/genkit.dart';

import 'runtime.dart';

/// A text of a [Knowledge] and how close it is to the question (cosine similarity, 1 = the same).
class KnowledgeHit {
  const KnowledgeHit(this.text, this.score);

  final String text;
  final double score;
}

/// A `knowledge` kind: texts with their embeddings, searched by meaning (RAG). Its `documents()` method gives the
/// first texts; [add] adds more; [search] gives the closest ones to put in a prompt.
abstract class Knowledge {
  /// The provider (connection name) whose embedder is used.
  String get embedderName => '';

  /// The texts the knowledge starts with (the kind's `documents` method).
  Future<List<String>> documents() async => const [];

  final List<(String, List<double>)> _items = [];
  bool _loaded = false;

  Future<List<List<double>>> _embed(List<String> texts) async {
    final out = await DragonflyGenkit.ai.embed(
      embedder: DragonflyGenkit.embedder(embedderName),
      documents: [for (final t in texts) DocumentData(content: [TextPart(text: t)])],
    );
    return [for (final e in out) e.embedding];
  }

  Future<void> add(List<String> texts) async {
    if (texts.isEmpty) return;
    final vectors = await _embed(texts);
    for (var i = 0; i < texts.length; i++) {
      _items.add((texts[i], vectors[i]));
    }
  }

  /// The [k] texts closest in meaning to [question].
  Future<List<KnowledgeHit>> search(String question, {int k = 4}) async {
    if (!_loaded) {
      _loaded = true;
      await add(await documents());
    }
    final q = (await _embed([question])).first;
    final hits = [for (final (text, v) in _items) KnowledgeHit(text, _cosine(q, v))]
      ..sort((a, b) => b.score.compareTo(a.score));
    return hits.take(k).toList();
  }

  /// The closest texts as one block for a prompt.
  Future<String> context(String question, {int k = 4}) async =>
      (await search(question, k: k)).map((h) => '- ${h.text}').join('\n');
}

double _cosine(List<double> a, List<double> b) {
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (var i = 0; i < math.min(a.length, b.length); i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  return na == 0 || nb == 0 ? 0 : dot / (math.sqrt(na) * math.sqrt(nb));
}
