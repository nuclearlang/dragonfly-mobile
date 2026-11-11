import 'package:clean_flutter_project/components/characters/domain/models/character.dart';
import 'package:clean_flutter_project/components/characters/domain/models/character_error.dart';
import 'package:clean_flutter_project/components/characters/domain/models/character_params.dart';
import 'package:clean_flutter_project/shared/models/page.dart';
import 'package:dragonfly/dragonfly.dart';
import 'package:fpdart/fpdart.dart';

/// Repository: each method is an http call. The path is appended to the connection's baseUrl;
/// `:id` takes the value of the `id` parameter, and the other parameters go to the query (GET) or the body.
/// saveLocal: a GET that answers a Character (or a list) saves it in the local table and gets getOneAsLocal(id) /
/// getManyAsLocal(ids), which answer the same from the device, without a request.
class CharacterRepository extends Repository {
  CharacterRepository() : super(path: 'character', saveLocal: true);

  Future<Either<CharacterError, Character>> getOne(int id) => attempt(
        () => send(
          HttpMethod.get,
          ':id',
          params: {'id': id},
          local: 'CharacterRepository.getOne',
          decode: Decode.one(Character.fromJson),
        ),
        Right.new,
        (e) => Left(CharacterError(message: e.message)),
      );

  /// What `getOne` last answered for these arguments, from the local database: no request.
  Future<Either<CharacterError, Character>> getOneAsLocal(int id) => attempt(
        () => recall(
          'CharacterRepository.getOne',
          ':id',
          params: {'id': id},
          decode: Decode.one(Character.fromJson),
        ),
        Right.new,
        (e) => Left(CharacterError(message: e.message)),
      );

  Future<Either<CharacterError, Page<Character>>> getPage(int page) => attempt(
        () => send(
          HttpMethod.get,
          '',
          params: {'page': page},
          cache: Cache(ttl: Duration(minutes: 10)),
          cacheName: 'CharacterRepository.getPage',
          decode: Decode.one((json) => Page<Character>.fromJson(json, (o) => Character.fromJson(o as Map<String, dynamic>))),
        ),
        Right.new,
        (e) => Left(CharacterError(message: e.message)),
      );

  void purgeGetPage() => purgeCache('CharacterRepository.getPage');

  /// the API answers 404 when no character has that name
  Future<Either<CharacterError, Page<Character>>> search(String name) => attempt(
        () => send(
          HttpMethod.get,
          '',
          params: {'name': name},
          decode: Decode.one((json) => Page<Character>.fromJson(json, (o) => Character.fromJson(o as Map<String, dynamic>))),
        ),
        Right.new,
        (e) => Left(CharacterError(message: e.message)),
      );

  Future<List<Character>> getMany(String ids) => send(
        HttpMethod.get,
        ':ids',
        pathParams: {'ids': ids},
        local: 'CharacterRepository.getMany',
        decode: Decode.list(Character.fromJson),
      );

  /// What `getMany` last answered for these arguments, from the local database: no request.
  Future<List<Character>> getManyAsLocal(String ids) => recall(
        'CharacterRepository.getMany',
        ':ids',
        pathParams: {'ids': ids},
        decode: Decode.list(Character.fromJson),
      );

  Future<Either<CharacterError, Character>> save(CharacterParams character) => attempt(
        () => send(
          HttpMethod.post,
          '',
          params: {'character': character},
          retry: 1,
          decode: Decode.one(Character.fromJson),
        ),
        Right.new,
        (e) => Left(CharacterError(message: e.message)),
      );

  /// the characters fetched so far, newest first: a query on the local table, no request
  Future<List<Character>> recent(int count) async {
    return await local<Character>().orderBy('created', desc: true).limit(count).getMany();
  }
}
