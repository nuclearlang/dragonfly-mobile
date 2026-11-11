import 'package:clean_flutter_project/components/characters/domain/models/character.dart';
import 'package:clean_flutter_project/components/characters/domain/models/character_error.dart';
import 'package:clean_flutter_project/components/characters/domain/models/character_params.dart';
import 'package:clean_flutter_project/components/characters/domain/usecases/get_one_character_usecase.dart';
import 'package:clean_flutter_project/components/characters/domain/usecases/get_page_usecase.dart';
import 'package:clean_flutter_project/components/characters/domain/usecases/save_character_usecase.dart';
import 'package:clean_flutter_project/components/characters/domain/usecases/search_characters_usecase.dart';
import 'package:dragonfly/dragonfly.dart';
import 'package:fpdart/fpdart.dart';

/// Application component: the facade of the component. Other components and the screens use
/// characters only through these functions.
class CharactersComponent {
  Future<Either<CharacterError, Character>> getOne(int id) async {
    return await inject<GetOneCharacterUseCase>().exec(id);
  }

  Future<Either<CharacterError, List<Character>>> getPage(int page) async {
    return await inject<GetPageUseCase>().exec(page);
  }

  Future<Either<CharacterError, Character>> save(CharacterParams character) async {
    return await inject<SaveCharacterUseCase>().exec(character);
  }

  Future<Either<CharacterError, List<Character>>> search(String name) async {
    return await inject<SearchCharactersUseCase>().exec(name);
  }
}
