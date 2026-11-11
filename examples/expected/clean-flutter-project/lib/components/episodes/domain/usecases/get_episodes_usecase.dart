import 'package:clean_flutter_project/components/episodes/data/episode_repository.dart';
import 'package:clean_flutter_project/components/episodes/domain/models/episode.dart';
import 'package:fpdart/fpdart.dart';

class GetEpisodesUseCase {
  GetEpisodesUseCase(this.repository);

  final EpisodeRepository repository;

  Future<Either<String, List<Episode>>> exec(List<int> ids) async {
    final episodes = await repository.getMany(ids.join(','));
    return Right(episodes);
  }
}
