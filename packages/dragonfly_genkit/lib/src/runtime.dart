import 'package:genkit/genkit.dart';

/// The Genkit instance of the app and the models and embedders of its providers, by connection name.
abstract final class DragonflyGenkit {
  static Genkit? _ai;
  static final Map<String, ModelRef<dynamic>> _models = {};
  static final Map<String, EmbedderRef<dynamic>> _embedders = {};

  /// The app's Genkit (started by the generated `startGenkit`).
  static Genkit get ai {
    final ai = _ai;
    if (ai == null) {
      throw StateError('Genkit is not started: enable plugins(genkit = true) and a provider in config.nuc, '
          'and list the provider (GoogleAI(...), FirebaseAI(...)...) in the connections of the project config');
    }
    return ai;
  }

  static bool get started => _ai != null;

  /// Starts Genkit with the plugins and the models of the providers (the generated `startGenkit` calls it).
  static void start({
    required List<GenkitPlugin> plugins,
    required Map<String, ModelRef<dynamic>> models,
    Map<String, EmbedderRef<dynamic>> embedders = const {},
  }) {
    // no .prompt files in an app: prompts are written in the .nuc
    _ai = Genkit(plugins: plugins, isDevEnv: false, promptDir: null);
    _models
      ..clear()
      ..addAll(models);
    _embedders
      ..clear()
      ..addAll(embedders);
  }

  /// Uses [ai] with [models] as they are (tests: a model of [FakeModels]).
  static void use(Genkit ai, Map<String, ModelRef<dynamic>> models, [Map<String, EmbedderRef<dynamic>> embedders = const {}]) {
    _ai = ai;
    _models
      ..clear()
      ..addAll(models);
    _embedders
      ..clear()
      ..addAll(embedders);
  }

  /// The model of the provider named [name] (`''`: the provider without `connectionName`).
  static ModelRef<dynamic> model([String name = '']) =>
      _models[name] ?? _models.values.firstOrNull ?? (throw StateError('no AI provider named "$name"'));

  /// The embedder of the provider named [name].
  static EmbedderRef<dynamic> embedder([String name = '']) =>
      _embedders[name] ??
      _embedders.values.firstOrNull ??
      (throw StateError('no AI provider with an embedder named "$name": give it embedder: "..."'));

  static Future<void> reset() async {
    await _ai?.shutdown();
    _ai = null;
    _models.clear();
    _embedders.clear();
  }
}

/// The text the model answers to [prompt] (with an optional [system] instruction).
Future<String> generateText(String prompt, {String model = '', String? system}) async {
  final r = await DragonflyGenkit.ai.generate(model: DragonflyGenkit.model(model), prompt: prompt, system: system);
  return r.text;
}

/// The text of [prompt] as it is generated.
Stream<String> streamText(String prompt, {String model = '', String? system}) {
  final stream = DragonflyGenkit.ai.generateStream(model: DragonflyGenkit.model(model), prompt: prompt, system: system);
  return stream.map((chunk) => chunk.text);
}
