import 'package:dragonfly/dragonfly.dart';
import 'package:dragonfly_genkit/dragonfly_genkit.dart';

/// The AI provider of the app: a local Ollama through its OpenAI-compatible API (no API key in the app).
class ProjectConfig extends AppConfig {
  @override
  final List<Connection> connections = [
    OpenAI(
      model: 'qwen3.5:4b',
      baseUrl: 'http://localhost:11434/v1',
      apiKey: 'ollama',
      embedder: 'embeddinggemma',
    ),
  ];
}
