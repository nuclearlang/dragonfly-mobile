import 'package:genkit/client.dart';
import 'package:schemantic/schemantic.dart';

import 'schemas.dart';

/// A `remote` kind: flows deployed on a Genkit server (Node, Go, Python, Dart), called like a repository calls an
/// API. Each method is one flow at `baseUrl/<path>`; one that returns a Stream streams its chunks.
abstract class RemoteFlows {
  /// The server (`@remote("https://...")` on the kind).
  String get baseUrl;

  /// Headers of every call (a session token): override to add them.
  Map<String, String> get headers => const {};

  String _url(String path) => '${baseUrl.replaceAll(RegExp(r'/$'), '')}/${path.replaceAll(RegExp(r'^/'), '')}';

  /// Calls the flow at [path] with [input].
  Future<O> callFlow<I, O>(String path, I input) {
    final action = defineRemoteAction<I, O, void, void>(
      url: _url(path),
      inputSchema: Schemas.of<I>(),
      outputSchema: Schemas.of<O>(),
      defaultHeaders: headers,
    );
    return action(input: input);
  }

  /// Streams the chunks of the flow at [path].
  Stream<C> streamFlow<I, C>(String path, I input) {
    final action = defineRemoteAction<I, dynamic, C, void>(
      url: _url(path),
      inputSchema: Schemas.of<I>(),
      outputSchema: SchemanticType.dynamicSchema(),
      streamSchema: Schemas.of<C>(),
      defaultHeaders: headers,
    );
    return action.stream(input: input);
  }
}
