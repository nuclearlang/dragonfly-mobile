import 'package:dragonfly/testing.dart';
import 'package:dragonfly_genkit/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit_assistant/components/assistant/ai/assistant.dart';
import 'package:genkit_assistant/components/assistant/ai/faq.dart';
import 'package:genkit_assistant/components/assistant/ai/note_tools.dart';
import 'package:genkit_assistant/dragonfly.g.dart';

void main() {
  group('AssistantTests', () {
    setUp(() async {
      await DragonflyTest.start(dragonflyConfig(), registerDragonfly);
    });

    setUp(() async {
      startFakeGenkit(['I saved it.', 'Hello!']);
    });

    test('the chat answers and the tools keep notes', () async {
      final notes = NoteTools();
      expect(notes.addNote('buy milk'), 'saved note 1: buy milk');
      expect(notes.listNotes(), '1. buy milk');
      expect(notes.tools().length, 2);
      final chat = Assistant(notes);
      expect(await chat.send('save buy milk'), 'I saved it.');
    });

    test('the knowledge finds the closest text', () async {
      final hits = await Faq().search('the assistant runs on a local Ollama model', k: 1);
      expect(hits.first.text, 'The assistant runs on a local Ollama model.');
    });
  });
}
