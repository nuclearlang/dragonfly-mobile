import 'package:clean_flutter_project/components/characters/data/character_repository.dart';
import 'package:clean_flutter_project/components/characters/domain/models/character.dart';
import 'package:clean_flutter_project/components/characters/domain/models/character_error.dart';
import 'package:fpdart/fpdart.dart';

class GetOneCharacterUseCase {
  GetOneCharacterUseCase(this.repository);

  final CharacterRepository repository;

  Future<Either<CharacterError, Character>> exec(int id) async {
    return await repository.getOne(id);
  }
}
