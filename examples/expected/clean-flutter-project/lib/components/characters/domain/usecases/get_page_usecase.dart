import 'package:clean_flutter_project/components/characters/data/character_repository.dart';
import 'package:clean_flutter_project/components/characters/domain/models/character.dart';
import 'package:clean_flutter_project/components/characters/domain/models/character_error.dart';
import 'package:clean_flutter_project/components/characters/domain/services/character_names.dart';
import 'package:clean_flutter_project/shared/models/page.dart';
import 'package:dragonfly/dragonfly.dart';
import 'package:fpdart/fpdart.dart';

class GetPageUseCase {
  GetPageUseCase(this.repository, this.names);

  final CharacterRepository repository;
  final CharacterNames names;

  Future<Either<CharacterError, List<Character>>> exec(int page) async {
    final denied = Guards.check(internet: true);
    if (denied != null) return Left(CharacterError(message: denied));
    final dataResult = await repository.getPage(page);
    if (dataResult case Left(:final value)) return Left(value);
    final data = (dataResult as Right<CharacterError, Page<Character>>).value;
    Log.d(
      'page loaded',
      data: {'page': page, 'count': data.results.length},
      at: 'characters › usecase › GetPageUseCase.exec · components/characters/domain/usecases/get_page_usecase.nuc:7',
    );
    return Right(names.alive(data.results));
  }
}
