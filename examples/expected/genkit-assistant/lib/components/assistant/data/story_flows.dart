import 'package:dragonfly_genkit/dragonfly_genkit.dart';

/// Flows of a Genkit server (deployed elsewhere), called like an API.
class StoryFlows extends RemoteFlows {
  @override
  String get baseUrl => 'http://localhost:3400';

  Future<String> tellJoke(String topic) => callFlow<String, String>('tellJoke', topic);

  Stream<String> story(String topic) => streamFlow<String, String>('streamStory', topic);
}
