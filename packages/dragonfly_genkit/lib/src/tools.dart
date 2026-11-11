import 'package:genkit/genkit.dart';

/// A `tools` kind: [tools] gives the Genkit tools of its methods with a doc comment (the dialect writes it); a
/// method without one is a helper of the others.
abstract class Tools {
  List<Tool> tools();
}

/// The tools of the dependencies of a chat or flow that are [Tools].
List<Tool> toolsOf(Iterable<Object?> dependencies) =>
    dependencies.whereType<Tools>().expand((t) => t.tools()).toList();
