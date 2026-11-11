import 'package:clean_flutter_project/components/characters/data/character_repository.dart';
import 'package:clean_flutter_project/components/characters/domain/models/character.dart';
import 'package:clean_flutter_project/components/characters/domain/models/character_error.dart';
import 'package:clean_flutter_project/shared/models/page.dart';
import 'package:fpdart/fpdart.dart';

class SearchCharactersUseCase {
  SearchCharactersUseCase(this.repository);

  final CharacterRepository repository;

  Future<Either<CharacterError, List<Character>>> exec(String name) async {
    final pageResult = await repository.search(name);
    if (pageResult case Left(:final value)) return Left(value);
    final page = (pageResult as Right<CharacterError, Page<Character>>).value;
    return Right(page.results);
  }
}
