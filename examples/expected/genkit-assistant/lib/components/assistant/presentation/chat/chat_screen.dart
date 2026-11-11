import 'package:dragonfly/dragonfly.dart';
import 'package:dragonfly_genkit/dragonfly_genkit.dart';
import 'package:flutter/material.dart' hide Summary;
import 'package:genkit_assistant/components/assistant/ai/assistant.dart';

/// The chat: the messages as they stream, and a box to write.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  ChatController controller = ChatController(inject<Assistant>());
  TextEditingController input = TextEditingController();

  void send() {
    final text = input.text;
    input.clear();
    controller.send(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Assistant')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, child) => Column(
          children: [
            Expanded(
              child: ListView(
                children: controller.messages.map((m) => ListTile(
                  title: Text(m.text),
                  leading: Icon(m.fromUser ? Icons.person : Icons.smart_toy),
                )).toList(),
              ),
            ),
            if (controller.sending) LinearProgressIndicator(),
            TextField(controller: input, onSubmitted: (text) => send()),
          ],
        ),
      ),
    );
  }
}
