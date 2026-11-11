import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../core.dart';
import 'cache.dart';
import 'connection.dart';
import 'errors.dart';
import '../local/local.dart';

enum HttpMethod { get, post, put, patch, delete }

/// Base of the classes of the `repository` kind. The transpiler writes one call to [send] per method.
abstract class Repository {
  Repository({this.path = '', this.connection = '', this.saveLocal = false});

  /// Added to the connection's baseUrl (`@repository(path = "characters")`).
  final String path;

  /// `connectionName` of the project config; `''` = the default connection.
  final String connection;

  /// `@repository(saveLocal = true)`: the GET methods save what they answer in the local database (the
  /// transpiler passes `local:` to [send] and writes the `<method>AsLocal()` twins).
  final bool saveLocal;

  Http get http => Dragonfly.connection<Http>(connection);

  /// The local table of [T] (`@repository(saveLocal = true)`, a model with `@primary`): CRUD and queries
  /// on the device, as a backend repository.
  LocalTable<T> local<T extends Object>() => Local.table<T>();

  /// One request. [path] is joined to the repository's path; `:name` in it takes the value of [params]
  /// or [pathParams]. The [params] not used in the path go to the query (GET, DELETE) or form the body
  /// (POST, PUT, PATCH: a single value is the body as it is). [retry] is the number of extra attempts;
  /// by default 2 for GET, PUT and DELETE and 0 for POST and PATCH, which are not idempotent. [local]
  /// (`Repository.method`) saves the decoded value in the local database, so [recall] with the same
  /// arguments answers it without network.
  Future<T> send<T>(
    HttpMethod method,
    String path, {
    Map<String, Object?> params = const {},
    Map<String, Object?> pathParams = const {},
    Map<String, Object?> query = const {},
    Object? body,
    Map<String, String> headers = const {},
    Cache? cache,
    String cacheName = '',
    int? retry,
    String? local,
    required T Function(Object? json) decode,
  }) async {
    final rest = Map<String, Object?>.of(params);
    final read = method == HttpMethod.get || method == HttpMethod.delete;
    final (url, q) = target(path, params: params, pathParams: pathParams, query: query, used: rest, read: read);
    final data = body ?? (read || rest.isEmpty ? null : (rest.length == 1 ? rest.values.first : rest));
    final key = cache == null ? null : cacheKey(cache.key ?? cacheName, url, q);
    if (key != null) {
      final hit = Dragonfly.cache.read(key);
      if (hit != null) return hit.value as T;
    }
    final attempts = 1 + (retry ?? (method == HttpMethod.post || method == HttpMethod.patch ? 0 : 2));
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await http.dio.request<Object?>(
          url,
          data: toJson(data),
          queryParameters: q.isEmpty ? null : q,
          options: Options(method: method.name.toUpperCase(), headers: headers.isEmpty ? null : headers),
        );
        final value = decode(response.data);
        if (key != null) Dragonfly.cache.write(key, value, cache!.ttl);
        if (local != null) await Local.store(cacheKey(local, url, q), value);
        return value;
      } on DioException catch (e) {
        final error = HttpError.from(e);
        if (attempt + 1 >= attempts || !error.transient) throw error;
        await Future<void>.delayed(backoff(attempt));
      }
    }
  }

  /// What [send] with [local] saved for these arguments, decoded with [decode]: the rows as they are now
  /// in the local table. Throws `NotFound` when that call never answered. The transpiler writes one per
  /// local method: `getOneAsLocal(id)`.
  Future<T> recall<T>(
    String local,
    String path, {
    Map<String, Object?> params = const {},
    Map<String, Object?> pathParams = const {},
    Map<String, Object?> query = const {},
    required T Function(Object? json) decode,
  }) async {
    final (url, q) = target(path, params: params, pathParams: pathParams, query: query);
    return decode(await Local.recall(cacheKey(local, url, q)));
  }

  /// The url and query of a request: the path with its `:name` values and the [params] left over
  /// (into the query when [read]).
  (String, Map<String, Object?>) target(
    String path, {
    Map<String, Object?> params = const {},
    Map<String, Object?> pathParams = const {},
    Map<String, Object?> query = const {},
    Map<String, Object?>? used,
    bool read = true,
  }) {
    final rest = used ?? Map<String, Object?>.of(params);
    final url = buildPath(join(this.path, path), {...pathParams, ...params}, used: rest);
    return (url, {...query, if (read) ...rest});
  }

  /// Runs [request]: its value goes through [ok] and a [RepositoryError] (an `HttpError`, a `NotFound`)
  /// through [err]. The transpiler uses it for methods that return an `Either` (fpdart):
  /// `attempt(() => send(...), Right.new, (e) => Left(MyError(message: e.message)))`.
  Future<R> attempt<T, R>(
    Future<T> Function() request,
    R Function(T value) ok,
    R Function(RepositoryError error) err,
  ) async {
    try {
      return ok(await request());
    } on RepositoryError catch (e) {
      return err(e);
    }
  }

  /// Removes the cached responses of [key] (a method's cacheKey, or `Repository.method`).
  void purgeCache(String key) => Dragonfly.cache.purge(key);

  static String join(String a, String b) {
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return '${a.endsWith('/') ? a.substring(0, a.length - 1) : a}/${b.startsWith('/') ? b.substring(1) : b}';
  }

  /// Replaces each `:name` of [path] with its encoded value; the names used are removed from [used].
  static String buildPath(String path, Map<String, Object?> values, {Map<String, Object?>? used}) {
    return path.replaceAllMapped(RegExp(r':([A-Za-z_][A-Za-z0-9_]*)'), (m) {
      final name = m[1]!;
      if (!values.containsKey(name)) {
        throw ArgumentError('the path "$path" uses :$name but the method has no parameter "$name"');
      }
      used?.remove(name);
      return Uri.encodeComponent('${values[name]}');
    });
  }

  static String cacheKey(String name, String url, Map<String, Object?> query) {
    final q = (query.keys.toList()..sort()).map((k) => '$k=${query[k]}').join('&');
    return '$name|$url?$q';
  }

  /// 300 ms, 600 ms, 1.2 s...
  static Duration backoff(int attempt) => Duration(milliseconds: 300 * math.pow(2, attempt).toInt());

  /// Models of json_serializable become maps; maps, lists and primitive values stay as they are.
  static Object? toJson(Object? value) {
    if (value == null || value is num || value is String || value is bool || value is Map || value is FormData) {
      return value;
    }
    if (value is List) return value.map(toJson).toList();
    return (value as dynamic).toJson();
  }
}

/// Decoders the transpiler passes to [Repository.send].
abstract final class Decode {
  /// `Character.fromJson` for one object.
  static T Function(Object?) one<T>(T Function(Map<String, dynamic>) fromJson) =>
      (json) => fromJson(json as Map<String, dynamic>);

  /// `Character.fromJson` for a list.
  static List<T> Function(Object?) list<T>(T Function(Map<String, dynamic>) fromJson) =>
      (json) => (json as List).map((e) => fromJson(e as Map<String, dynamic>)).toList();

  /// A value as it comes (int, String, a map...).
  static T value<T>(Object? json) => json as T;

  /// A list of values.
  static List<T> values<T>(Object? json) => (json as List).cast<T>();

  /// No body (`void`).
  static void none(Object? json) {}
}
