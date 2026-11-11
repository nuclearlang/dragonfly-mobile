import 'package:genkit/genkit.dart';

import 'runtime.dart';
import 'schemas.dart';

/// A `flow` kind: one AI operation with a typed input and output, registered as a Genkit flow (traces, the Developer
/// UI). Call it like a function: `~summarize(text)`.
abstract class GenkitFlow<I, O> {
  /// The flow's name (the class name in camelCase).
  String get flowName;

  /// What the flow does with its input (the kind's `run` method).
  Future<O> run(I input);

  late final Flow<I, O, void, void> _flow = DragonflyGenkit.ai.defineFlow<I, O, void, void>(
    name: flowName,
    inputSchema: Schemas.of<I>(),
    outputSchema: Schemas.of<O>(),
    fn: (input, _) => run(input),
  );

  Future<O> call(I input) => _flow(input);
}
