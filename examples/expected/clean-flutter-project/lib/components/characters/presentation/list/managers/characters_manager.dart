import 'package:clean_flutter_project/components/characters/characters_component.dart';
import 'package:clean_flutter_project/components/characters/domain/models/character.dart';
import 'package:clean_flutter_project/components/characters/domain/models/character_error.dart';
import 'package:clean_flutter_project/components/characters/presentation/list/state_models/characters_state.dart';
import 'package:dragonfly/dragonfly.dart';
import 'package:fpdart/fpdart.dart';

class CharactersManager extends StateManager<CharactersState> {
  CharactersManager(this.characters) : super(const CharactersState.initial()) {
    loadPage(1);
  }

  final CharactersComponent characters;

  void loading() => emit(CharactersState.loading());

  Future<void> loadPage(int page) async {
    loading();
    final result = await _loadPage(page);
    emit(result.match(CharactersState.error, CharactersState.full));
  }

  Future<Either<CharacterError, List<Character>>> _loadPage(int page) async {
    return await characters.getPage(page);
  }
}
