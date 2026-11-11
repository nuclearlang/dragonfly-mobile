import 'package:dragonfly/dragonfly.dart';

/// An AI provider of the project config: a model (and optionally an embedder) of one Genkit plugin. The app's
/// generated `dragonfly_genkit.g.dart` turns each one into its plugin, only for the providers the project enables
/// (`plugins(googleAI = true)` in config.nuc), so an app carries only the plugins it uses.
abstract class AiProvider implements Connection {
  AiProvider({String connectionName = '', required this.model, this.embedder}) : name = connectionName;

  @override
  final String name;

  /// The model: `gemini-flash-latest`, `gpt-4o-mini`, `claude-sonnet-4-5`...
  final String model;

  /// The embedder for the knowledge base: `text-embedding-004`, `text-embedding-3-small`...
  final String? embedder;
}

/// Gemini through Firebase AI Logic (App Check, no API key in the app). The app must call Firebase.initializeApp.
class FirebaseAI extends AiProvider {
  FirebaseAI({super.connectionName, super.model = 'gemini-flash-latest', this.vertexAI = false})
      : super(embedder: null);

  /// true: the Agent Platform (Vertex AI) backend of Firebase AI Logic; false: the Gemini Developer API.
  final bool vertexAI;
}

/// Gemini with an API key (GEMINI_API_KEY, or [apiKey]): for development.
class GoogleAI extends AiProvider {
  GoogleAI({super.connectionName, super.model = 'gemini-flash-latest', super.embedder, this.apiKey});

  final String? apiKey;
}

/// Gemini and other models on Google Cloud's Vertex AI.
class VertexAI extends AiProvider {
  VertexAI({super.connectionName, super.model = 'gemini-flash-latest', super.embedder, this.projectId, this.location});

  final String? projectId;
  final String? location;
}

/// OpenAI, or any OpenAI-compatible server through [baseUrl] (a local Ollama: `http://localhost:11434/v1`).
class OpenAI extends AiProvider {
  OpenAI({super.connectionName, super.model = 'gpt-4o-mini', super.embedder, this.apiKey, this.baseUrl});

  final String? apiKey;
  final String? baseUrl;
}

/// Anthropic's Claude models (ANTHROPIC_API_KEY, or [apiKey]).
class Anthropic extends AiProvider {
  Anthropic({super.connectionName, super.model = 'claude-sonnet-4-5', this.apiKey}) : super(embedder: null);

  final String? apiKey;
}
