import 'package:clean_flutter_project/components/characters/domain/models/character.dart';

/// Service: transformations used by the use cases.
class CharacterNames {
  List<Character> alive(List<Character> characters) {
    return characters.where((c) => c.status == 'Alive').toList();
  }
}
