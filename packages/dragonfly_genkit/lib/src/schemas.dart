import 'dart:convert';

import 'package:schemantic/schemantic.dart';

import 'runtime.dart';

/// The schemas of the app's models (`Character`: a JSON schema of its fields + its fromJson), registered by the
/// generated `dragonfly_genkit.g.dart`: what a flow reads and answers and what the model's structured output is.
abstract final class Schemas {
  static final Map<Type, SchemanticType<Object?>> _byType = {};

  static void register<T>(SchemanticType<T> schema) => _byType[T] = schema as SchemanticType<Object?>;

  /// The schema of [T]: a model of the app, or a basic type (String, int, double, bool).
  static SchemanticType<T> of<T>() {
    final basic = switch (T) {
      const (String) => SchemanticType.string(),
      const (int) => SchemanticType.integer(),
      const (double) => SchemanticType.doubleSchema(),
      const (bool) => SchemanticType.boolean(),
      _ => null,
    };
    if (basic != null) return basic as SchemanticType<T>;
    final found = _byType[T];
    if (found == null) throw StateError('no schema for $T: only the models of the app (domain/models) have one');
    return found as SchemanticType<T>;
  }

  /// A JSON schema object with [properties] (name → JSON schema) and the [required] names: a tool's input.
  static SchemanticType<Map<String, dynamic>> object(Map<String, Object?> properties, List<String> required) =>
      SchemanticType.from(
        jsonSchema: {'type': 'object', 'properties': properties, 'required': required},
        parse: (json) => Map<String, dynamic>.from(json as Map),
      );
}

/// Structured output: the model answers [prompt] as a [T] (a model of the app, validated by its schema).
Future<T> generateObject<T>(String prompt, {String model = '', String? system}) async {
  final schema = Schemas.of<T>();
  final r = await DragonflyGenkit.ai.generate<T, dynamic>(
    model: DragonflyGenkit.model(model),
    prompt: prompt,
    system: system,
    outputSchema: schema,
    outputFormat: 'json',
  );
  final out = r.output;
  if (out != null) return out;
  // a provider without structured output (an OpenAI-compatible server) answers the JSON as text
  final text = r.text.trim();
  final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text)?.group(1);
  final start = (fenced ?? text).indexOf('{');
  final end = (fenced ?? text).lastIndexOf('}');
  if (start < 0 || end < start) throw StateError('the model gave no ${T.toString()}: $text');
  return schema.parse(jsonDecode((fenced ?? text).substring(start, end + 1)));
}
