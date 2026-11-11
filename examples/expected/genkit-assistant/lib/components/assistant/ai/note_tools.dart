import 'package:dragonfly_genkit/dragonfly_genkit.dart';

/// The tools of the assistant: notes kept in memory.
class NoteTools extends Tools {
  List<String> notes = [];

  /// Saves a note with the given text.
  String addNote(String text) {
    notes.add(text);
    return 'saved note ${notes.length}: $text';
  }

  /// Lists every saved note, one per line.
  String listNotes() {
    if (notes.isEmpty) {
      return 'there are no notes';
    }
    return numbered(notes);
  }

  String numbered(List<String> items) {
    return List.generate(items.length - 0, (i) => 0 + i).map((i) => '${i + 1}. ${items[i]}').toList().join('\n');
  }

  /// The tools the model can call: the methods with a doc comment.
  @override
  List<Tool> tools() => [
        Tool<Map<String, dynamic>, Object?>(
          name: 'addNote',
          description: 'Saves a note with the given text.',
          inputSchema: Schemas.object({ 'text': {'type': 'string'} }, ['text', ]),
          fn: (input, _) async => ToolResult.response(addNote(input['text'] as String)),
        ),
        Tool<Map<String, dynamic>, Object?>(
          name: 'listNotes',
          description: 'Lists every saved note, one per line.',
          inputSchema: Schemas.object({  }, []),
          fn: (input, _) async => ToolResult.response(listNotes()),
        ),
      ];
}
