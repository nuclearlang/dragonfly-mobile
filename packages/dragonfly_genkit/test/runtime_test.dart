import 'package:dragonfly_genkit/dragonfly_genkit.dart';
import 'package:dragonfly_genkit/testing.dart';
import 'package:flutter_test/flutter_test.dart';

class Weather extends Tools {
  String weather(String city) => 'sunny in $city';

  @override
  List<Tool> tools() => [
        Tool<Map<String, dynamic>, String>(
          name: 'weather',
          description: 'The weather of a city.',
          inputSchema: Schemas.object({'city': {'type': 'string'}}, ['city']),
          fn: (input, _) => ToolResult.response(weather(input['city'] as String)),
        ),
      ];
}

class Helper extends Chat {
  Helper(this.weather);

  final Weather weather;

  @override
  String get prompt => 'Be brief.';

  @override
  List<Object?> get dependencies => [weather];
}

class Shout extends GenkitFlow<String, String> {
  @override
  String get flowName => 'shout';

  @override
  Future<String> run(String input) async => '${await generateText(input)}!';
}

class Facts extends Knowledge {
  @override
  Future<List<String>> documents() async => ['cats sleep a lot', 'rockets fly to space', 'the sea is salty'];
}

void main() {
  setUp(() => startFakeGenkit(['hello there', 'second answer']));
  tearDown(DragonflyGenkit.reset);

  test('a chat answers, keeps its history and streams through a controller', () async {
    final chat = Helper(Weather());
    expect(await chat.send('hi'), 'hello there');
    expect(chat.history.length, 2);
    final controller = ChatController(chat);
    await controller.send('again');
    expect(controller.messages.map((m) => m.text).toList(), ['again', 'second answer']);
    expect(controller.sending, isFalse);
    expect(toolsOf(chat.dependencies).map((t) => t.name).toList(), ['weather']);
  });

  test('a flow runs through Genkit; the knowledge finds the closest text', () async {
    expect(await Shout()('ping'), 'hello there!');
    final hits = await Facts().search('do cats sleep?', k: 1);
    expect(hits.single.text, 'cats sleep a lot');
    expect(Schemas.of<String>(), isNotNull);
  });
}
