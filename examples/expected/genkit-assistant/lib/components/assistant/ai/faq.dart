import 'package:dragonfly_genkit/dragonfly_genkit.dart';

/// What the assistant knows about the app, searched by meaning.
class Faq extends Knowledge {
  @override
  Future<List<String>> documents() async {
    return [
      'Notes are kept only while the app is open.',
      'The assistant runs on a local Ollama model.',
      'Summaries have a title and at most three points.',
    ];
  }
}
