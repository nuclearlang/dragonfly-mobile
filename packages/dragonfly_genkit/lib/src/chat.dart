import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:genkit/genkit.dart';

import 'runtime.dart';
import 'tools.dart';

/// A `chat` kind: a conversation with a model, its system [prompt] and the tools of its dependencies. It keeps the
/// history of the conversation; [send] answers at once, [stream] piece by piece.
abstract class Chat {
  /// The provider (connection name) whose model answers.
  String get model => '';

  /// The system instruction.
  String get prompt => '';

  /// The constructor's dependencies: the [Tools] among them are offered to the model (the dialect writes it).
  List<Object?> get dependencies => const [];

  final List<Message> history = [];

  List<Tool> get _tools => toolsOf(dependencies);

  List<Message> _ask(String text) {
    history.add(Message(role: Role.user, content: [TextPart(text: text)]));
    return [
      if (prompt.isNotEmpty) Message(role: Role.system, content: [TextPart(text: prompt)]),
      ...history,
    ];
  }

  /// The model's answer to [text], remembered in [history].
  Future<String> send(String text) async {
    final r = await DragonflyGenkit.ai.generate(model: DragonflyGenkit.model(model), messages: _ask(text), tools: _tools);
    history.add(Message(role: Role.model, content: [TextPart(text: r.text)]));
    return r.text;
  }

  /// The answer to [text] as it is generated; the whole answer goes to [history] when it ends.
  Stream<String> stream(String text) async* {
    final s = DragonflyGenkit.ai.generateStream(model: DragonflyGenkit.model(model), messages: _ask(text), tools: _tools);
    final answer = StringBuffer();
    await for (final chunk in s) {
      answer.write(chunk.text);
      yield chunk.text;
    }
    // a model that does not stream gives the whole answer at the end
    if (answer.isEmpty) {
      final whole = (await s.onResult).text;
      answer.write(whole);
      if (whole.isNotEmpty) yield whole;
    }
    history.add(Message(role: Role.model, content: [TextPart(text: answer.toString())]));
  }

  void clear() => history.clear();
}

/// One message of a [ChatController]: who wrote it and its text (it grows while the answer streams).
class ChatMessage {
  ChatMessage({required this.fromUser, required this.text});

  final bool fromUser;
  String text;
}

/// The state of a chat screen: the messages, whether an answer is coming and the last error. Listen to it with a
/// ListenableBuilder; [send] streams the answer into the last message.
class ChatController extends ChangeNotifier {
  ChatController(this.chat);

  final Chat chat;
  final List<ChatMessage> messages = [];
  bool sending = false;
  Object? error;

  Future<void> send(String text) async {
    if (text.trim().isEmpty || sending) return;
    messages.add(ChatMessage(fromUser: true, text: text));
    final answer = ChatMessage(fromUser: false, text: '');
    messages.add(answer);
    sending = true;
    error = null;
    notifyListeners();
    try {
      await for (final piece in chat.stream(text)) {
        answer.text += piece;
        notifyListeners();
      }
    } catch (e) {
      error = e;
      messages.remove(answer);
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  void clear() {
    messages.clear();
    chat.clear();
    notifyListeners();
  }
}
