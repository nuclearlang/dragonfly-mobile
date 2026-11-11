import 'package:clean_flutter_project/components/episodes/domain/models/episode.dart';
import 'package:dragonfly/dragonfly.dart';

class EpisodeRepository extends Repository {
  EpisodeRepository() : super(path: 'episode');

  Future<List<Episode>> getMany(String ids) => send(
        HttpMethod.get,
        ':ids',
        params: {'ids': ids},
        decode: Decode.list(Episode.fromJson),
      );
}
