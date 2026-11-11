import 'package:dragonfly/dragonfly.dart';
import 'package:flutter/material.dart' hide Page;

/// /characters/7 opens this screen with id = 7; so does context.pushTo(CharacterDetailScreen(id = 7)).
class CharacterDetailScreen extends StatelessWidget {
  const CharacterDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Character $id')),
      body: Center(child: TextButton(onPressed: () => context.goBack(), child: Text('Back'))),
    );
  }
}
