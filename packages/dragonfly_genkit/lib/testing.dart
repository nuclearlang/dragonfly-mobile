/// Tests of apps with Genkit: a model that answers fixed texts and an embedder that needs no network.
library;

import 'package:genkit/genkit.dart';

import 'src/runtime.dart';

/// Starts Genkit with a fake model that answers [answers] in order (repeating the last one) and a fake embedder
/// (a vector of letter counts: texts with the same words are close).
void startFakeGenkit(List<String> answers) {
  final ai = Genkit(isDevEnv: false, promptDir: null);
  var i = 0;
  ai.defineModel(
    name: 'dragonfly/fake',
    fn: (request, _) async {
      final text = answers.isEmpty ? '' : answers[i < answers.length ? i++ : answers.length - 1];
      return ModelResponse(
        finishReason: FinishReason.stop,
        message: Message(role: Role.model, content: [TextPart(text: text)]),
      );
    },
  );
  ai.defineEmbedder(
    name: 'dragonfly/fake-embedder',
    fn: (request, _) async => EmbedResponse(
      embeddings: [for (final d in request.input) Embedding(embedding: _letters(d.content.map((p) => p.text ?? '').join(' ')))],
    ),
  );
  DragonflyGenkit.use(ai, {'': modelRef('dragonfly/fake')}, {'': embedderRef('dragonfly/fake-embedder')});
}

List<double> _letters(String text) {
  final v = List<double>.filled(26, 0);
  for (final c in text.toLowerCase().codeUnits) {
    if (c >= 97 && c <= 122) v[c - 97]++;
  }
  return v;
}
