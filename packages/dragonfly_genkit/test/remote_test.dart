import 'dart:io';

import 'package:dragonfly_genkit/dragonfly_genkit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/io.dart';

class StoryFlows extends RemoteFlows {
  @override
  String get baseUrl => 'http://localhost:3499';

  Future<String> tellJoke(String topic) => callFlow<String, String>('tellJoke', topic);

  Stream<String> story(String topic) => streamFlow<String, String>('streamStory', topic);
}

void main() {
  test('remote flows: a call and a stream against a real Genkit server', () async {
    final server = Genkit(isDevEnv: false, promptDir: null);
    final joke = server.defineFlow<String, String, void, void>(
      name: 'tellJoke',
      inputSchema: SchemanticType.string(),
      outputSchema: SchemanticType.string(),
      fn: (topic, _) async => 'a joke about $topic',
    );
    final story = server.defineFlow<String, String, String, void>(
      name: 'streamStory',
      inputSchema: SchemanticType.string(),
      outputSchema: SchemanticType.string(),
      streamSchema: SchemanticType.string(),
      fn: (topic, ctx) async {
        for (final w in ['once', 'upon', topic]) {
          ctx.sendChunk(w);
        }
        return 'done';
      },
    );
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 3499);
    final router = GenkitRouter()..addAction(joke)..addAction(story);
    http.listen((r) => router.handleHttpRequest(r));
    final flows = StoryFlows();
    expect(await flows.tellJoke('dart'), 'a joke about dart');
    expect(await flows.story('dragons').toList(), ['once', 'upon', 'dragons']);
    await http.close(force: true);
  });
}
