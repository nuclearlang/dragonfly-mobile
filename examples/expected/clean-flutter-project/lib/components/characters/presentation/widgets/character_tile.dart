import 'package:clean_flutter_project/components/characters/domain/models/character.dart';
import 'package:clean_flutter_project/components/characters/presentation/detail/character_detail_screen.dart';
import 'package:dragonfly/dragonfly.dart';
import 'package:flutter/material.dart' hide Page;

class CharacterTile extends StatelessWidget {
  const CharacterTile({super.key, required this.character});

  final Character character;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(backgroundImage: NetworkImage(character.image)),
      title: Text(character.name),
      subtitle: Text(character.species),
      trailing: Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => context.pushTo(CharacterDetailScreen(id: character.id)),
    );
  }
}
