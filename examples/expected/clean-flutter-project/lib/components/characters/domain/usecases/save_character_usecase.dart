import 'package:clean_flutter_project/components/characters/data/character_repository.dart';
import 'package:clean_flutter_project/components/characters/domain/models/character.dart';
import 'package:clean_flutter_project/components/characters/domain/models/character_error.dart';
import 'package:clean_flutter_project/components/characters/domain/models/character_params.dart';
import 'package:dragonfly/dragonfly.dart';
import 'package:fpdart/fpdart.dart';

class SaveCharacterUseCase {
  SaveCharacterUseCase(this.repository);

  final CharacterRepository repository;

  Future<Either<CharacterError, Character>> exec(CharacterParams character) async {
    final denied = Guards.check(session: true);
    if (denied != null) return Left(CharacterError(message: denied));
    final savedResult = await repository.save(character);
    if (savedResult case Left(:final value)) return Left(value);
    final saved = (savedResult as Right<CharacterError, Character>).value;
    repository.purgeGetPage();
    return Right(saved);
  }
}
