import 'package:flutter/material.dart' hide Summary;
import 'package:genkit_assistant/dragonfly.g.dart';

Future<void> main() async {
  await startDragonfly();
  runApp(App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(title: 'Assistant', routerConfig: appRouter);
  }
}
