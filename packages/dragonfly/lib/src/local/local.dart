import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../http/errors.dart';

/// A row the local database does not have (`find`, `getOne`, a `<method>AsLocal()` never answered).
class NotFound implements RepositoryError {
  const NotFound(this.message);

  @override
  final String message;

  @override
  String toString() => 'NotFound($message)';
}

/// How the local database is kept, set in the project config (`local` of `appConfig`) and, for the tables of
/// one component's models, in its config (`local` of `config`).
class LocalDatabase {
  const LocalDatabase({this.encrypted = true});

  /// AES-256 with a key generated once and kept in the device's secure storage (Keychain, Keystore, libsecret,
  /// DPAPI, WebCrypto). Off: the rows are plain text on disk (IndexedDB on web). Changing it after the first
  /// run needs the tables cleared: a box is read with the cipher it was written with.
  final bool encrypted;
}

/// The local database of the app: one table per model with a `@primary` (or `@generated`) field, the same
/// tables, queries and CRUD as a backend repository, on the device (hive_ce: a file per table on Android, iOS,
/// Linux, macOS and Windows, IndexedDB on web; encrypted as [LocalDatabase] says).
///
/// The transpiler registers the tables (`Local.register(Character.table)`) and a repository with
/// `@repository(saveLocal = true)` saves what its http methods answer ([store]) so `<method>AsLocal()` reads
/// it back ([recall]) without network. `local<Character>()` in a repository is the table itself.
abstract final class Local {
  static final Map<Type, LocalTable<Object>> _tables = {};

  /// Tables live in memory and are not encrypted (tests): `DragonflyTest.start` sets it.
  static bool memory = false;

  /// Where the encryption key is kept (`dragonfly.local.key`).
  static FlutterSecureStorage storage = const FlutterSecureStorage();

  static const String keyName = 'dragonfly.local.key';

  /// The table (box) that remembers which rows each http call answered.
  static const String callsTable = 'dragonfly_calls';

  static bool _started = false;
  static HiveCipher? _cipher;
  static final Map<String, LocalDatabase> _settings = {};

  /// Takes the `local` of the project config ([component] `''`) or of a component's config.
  static void configure(LocalDatabase? db, {String component = ''}) {
    if (db != null) _settings[component] = db;
  }

  /// How the tables of [component] are kept: its config's `local`, else the project's, else encrypted.
  static LocalDatabase settings([String? component]) =>
      _settings[component ?? ''] ?? _settings[''] ?? const LocalDatabase();

  /// Registers the table of [T] (of the models of [component]); a second registration of the same model
  /// replaces the first.
  static void register<T extends Object>(LocalTable<T> table, {String? component}) {
    table.component = component;
    _tables[T] = table;
  }

  /// The table of [T]; a model without `@primary` has none.
  static LocalTable<T> table<T extends Object>() {
    final t = _tables[T];
    if (t is LocalTable<T>) return t;
    throw StateError('$T has no local table: give it a @primary (or @generated) field');
  }

  /// Every registered table.
  static Iterable<LocalTable<Object>> get tables => _tables.values;

  static LocalTable<Object> _tableOf(Object value) {
    final t = _tables[value.runtimeType];
    if (t == null) {
      throw StateError(
        '${value.runtimeType} has no local table: give it a @primary (or @generated) field, '
        'or take `local` off the method that returns it',
      );
    }
    return t;
  }

  /// Opens the database once: the folder of the app (not on web).
  static Future<void> start() async {
    if (_started) return;
    _started = true;
    if (!memory && !kIsWeb) Hive.init((await getApplicationSupportDirectory()).path);
  }

  static Future<List<int>> _key() async {
    var saved = await storage.read(key: keyName);
    if (saved == null) {
      saved = base64Encode(Hive.generateSecureKey());
      await storage.write(key: keyName, value: saved);
    }
    return base64Decode(saved);
  }

  /// The box named [name], opened as the settings of [component] say (in memory and plain when [memory]).
  static Future<Box<String>> open(String name, {String? component}) async {
    await start();
    if (Hive.isBoxOpen(name)) return Hive.box<String>(name);
    final encrypted = !memory && settings(component).encrypted;
    return Hive.openBox<String>(
      name,
      encryptionCipher: encrypted ? _cipher ??= HiveAesCipher(await _key()) : null,
      bytes: memory ? Uint8List(0) : null,
    );
  }

  /// Saves what the http call [call] answered: the rows of [value] (a model or a list of models) go to
  /// their table and [call] remembers which they were.
  static Future<void> store(String call, Object? value) async {
    final calls = await open(callsTable);
    if (value is List) {
      if (value.isEmpty) {
        await calls.put(call, jsonEncode({'keys': <Object>[]}));
        return;
      }
      final table = _tableOf(value.first as Object);
      final keys = <Object>[];
      for (final item in value) {
        keys.add(table.keyOf(await table.put(item as Object)));
      }
      await calls.put(call, jsonEncode({'table': table.name, 'keys': keys}));
    } else if (value != null) {
      final table = _tableOf(value);
      final key = table.keyOf(await table.put(value));
      await calls.put(call, jsonEncode({'table': table.name, 'key': key}));
    }
  }

  /// The JSON the call [call] stored, read from its table (the rows as they are now): a map, or a list of
  /// maps. [NotFound] when the call never stored anything or its row was removed.
  static Future<Object?> recall(String call) async {
    final calls = await open(callsTable);
    final raw = calls.get(call);
    if (raw == null) throw NotFound('nothing saved locally for $call');
    final entry = jsonDecode(raw) as Map<String, dynamic>;
    final table = entry['table'] as String?;
    final box = table == null ? null : await _boxNamed(table);
    if (entry.containsKey('key')) {
      final row = box?.get(entry['key']);
      if (row == null) throw NotFound('the row of $call is no longer in the local table');
      return jsonDecode(row);
    }
    return [
      for (final key in entry['keys'] as List)
        if (box?.get(key) case final String row) jsonDecode(row),
    ];
  }

  static Future<Box<String>> _boxNamed(String name) async {
    for (final t in _tables.values) {
      if (t.name == name) return t.box;
    }
    return open(name);
  }

  /// Closes the database and forgets the tables (tests; `Dragonfly.reset` calls it).
  static Future<void> reset() async {
    await Hive.close();
    _tables.clear();
    _settings.clear();
    _cipher = null;
    _started = false;
  }
}

/// One local table: the rows of model [T] by its `@primary` field, as JSON (`toJson`/`fromJson`).
/// CRUD without writing it ([find], [findAll], [save], [remove]) and a query builder ([where], [orderBy],
/// [limit], [offset], then `getOne`, `getMany`, `count`, `exists`, `update`, `delete`).
class LocalTable<T extends Object> {
  LocalTable(String name, this.fromJson, {required this.key, this.generated = false, this.created, this.updated})
    : name = 'dragonfly_$name';

  /// The box name: `dragonfly_` + the model's name in snake_case, or the name `@entity("...")` gives.
  final String name;

  /// The component the model belongs to: its config's `local` says how the table is kept.
  String? component;
  final T Function(Map<String, dynamic> json) fromJson;

  /// JSON name of the `@primary` / `@generated` field.
  final String key;

  /// `@generated`: a row saved with a null key gets the next number.
  final bool generated;

  /// JSON names of the `@created` / `@updated` fields, stamped by the table.
  final String? created;
  final String? updated;

  Future<Box<String>> get box => Local.open(name, component: component);

  Map<String, dynamic> toJson(T value) => (value as dynamic).toJson() as Map<String, dynamic>;

  Map<String, dynamic> _row(String raw) => jsonDecode(raw) as Map<String, dynamic>;

  /// The box key of a row: hive keys are `int` or `String`.
  Object keyOf(Map<String, dynamic> row) {
    final id = row[key];
    return id is int || id is String ? id : '$id';
  }

  Object _key(Object id) => id is int || id is String ? id : '$id';

  // --- CRUD ---

  Future<Either<NotFound, T>> find(Object id) async {
    final raw = (await box).get(_key(id));
    return raw == null ? Left(NotFound('$T $id not found')) : Right(fromJson(_row(raw)));
  }

  Future<List<T>> findAll() => query().getMany();

  /// Writes [value] (a new row or the one with its key) and returns it as saved (with its generated key
  /// and stamps).
  Future<T> save(T value) async => fromJson(await put(value));

  Future<List<T>> saveAll(Iterable<T> values) async => [for (final v in values) await save(v)];

  /// Deletes the row [id]; false when there was none.
  Future<bool> remove(Object id) async {
    final b = await box;
    final k = _key(id);
    if (!b.containsKey(k)) return false;
    await b.delete(k);
    return true;
  }

  Future<void> clear() async => (await box).clear();

  /// Writes the JSON of [value] and returns the row written.
  Future<Map<String, dynamic>> put(Object value) => putRow(toJson(value as T));

  /// Writes [row]: a null `@generated` key gets the next number; `@created` is set when the row has none,
  /// `@updated` always.
  Future<Map<String, dynamic>> putRow(Map<String, dynamic> row) async {
    final b = await box;
    final json = Map<String, dynamic>.of(row);
    final now = DateTime.now().toIso8601String();
    if (created != null && json[created] == null) json[created!] = now;
    if (updated != null) json[updated!] = now;
    if (json[key] == null) {
      if (!generated) throw StateError('$T.$key is null: a @primary value is needed to save it locally');
      // the auto-increment key of hive, written into the row itself
      final id = await b.add('');
      json[key] = id;
      await b.put(id, jsonEncode(json));
    } else {
      await b.put(keyOf(json), jsonEncode(json));
    }
    return json;
  }

  // --- the query builder, started from the table ---

  LocalQuery<T> query() => LocalQuery<T>(this);

  LocalQuery<T> where(Map<String, Object?> conditions) => query().where(conditions);

  LocalQuery<T> orderBy(String field, {bool desc = false}) => query().orderBy(field, desc: desc);

  LocalQuery<T> limit(int n) => query().limit(n);

  LocalQuery<T> offset(int n) => query().offset(n);

  Future<Either<NotFound, T>> getOne() => query().getOne();

  Future<List<T>> getMany() => query().getMany();

  Future<int> count() => query().count();

  Future<bool> exists() => query().exists();

  Future<PageOf<T>> paginate(int page, [int size = 20]) => query().paginate(page, size);
}

/// One page of a query (Nuclear's `Page<T>`, ADR-0100): [items], [page] (from 1), [size], [total] rows and [pages].
/// The same class reads a backend's paged answer (`PageOf.fromJson(json, Task.fromJson)`).
class PageOf<T> {
  const PageOf({required this.items, required this.page, required this.size, required this.total, required this.pages});

  factory PageOf.fromJson(Map<String, dynamic> json, T Function(Object? json) fromJsonT) => PageOf(
    items: (json['items'] as List).map(fromJsonT).toList(),
    page: json['page'] as int,
    size: json['size'] as int,
    total: json['total'] as int,
    pages: json['pages'] as int,
  );

  final List<T> items;
  final int page;
  final int size;
  final int total;
  final int pages;

  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) => {
    'items': items.map(toJsonT).toList(),
    'page': page,
    'size': size,
    'total': total,
    'pages': pages,
  };
}

/// One query of a table. [where], [orderBy], [limit] and [offset] add to it; the others run it.
class LocalQuery<T extends Object> {
  LocalQuery(this.table);

  final LocalTable<T> table;
  final List<(String, Object?)> _conditions = [];
  final List<(String, bool)> _orders = [];
  int? _limit;
  int? _offset;

  /// Equality (`{'done': true}`) or an operator (`{'age': gt(18)}`, `{'name': like('Ri%')}`).
  LocalQuery<T> where(Map<String, Object?> conditions) {
    for (final e in conditions.entries) {
      _conditions.add((e.key, e.value));
    }
    return this;
  }

  LocalQuery<T> orderBy(String field, {bool desc = false}) {
    _orders.add((field, desc));
    return this;
  }

  LocalQuery<T> limit(int n) {
    _limit = n;
    return this;
  }

  LocalQuery<T> offset(int n) {
    _offset = n;
    return this;
  }

  bool _matches(Map<String, dynamic> row) => _conditions.every((c) {
    final value = row[c.$1];
    final cond = c.$2;
    return cond is Op ? cond.test(value) : value == cond;
  });

  int _compare(Map<String, dynamic> a, Map<String, dynamic> b) {
    for (final (field, desc) in _orders) {
      final r = compareValues(a[field], b[field]);
      if (r != 0) return desc ? -r : r;
    }
    return 0;
  }

  /// The matching rows, in order, without limit nor offset.
  Future<List<Map<String, dynamic>>> _matching() async {
    final rows = (await table.box).values.map(table._row).where(_matches).toList();
    if (_orders.isNotEmpty) rows.sort(_compare);
    return rows;
  }

  Future<List<Map<String, dynamic>>> _rows() async {
    var rows = await _matching();
    if (_offset != null) rows = rows.skip(_offset!).toList();
    if (_limit != null) rows = rows.take(_limit!).toList();
    return rows;
  }

  Future<Either<NotFound, T>> getOne() async {
    final rows = await limit(1)._rows();
    return rows.isEmpty ? Left(NotFound('$T not found')) : Right(table.fromJson(rows.first));
  }

  Future<List<T>> getMany() async => (await _rows()).map(table.fromJson).toList();

  /// Rows that match the conditions (limit and offset do not count).
  Future<int> count() async => (await _matching()).length;

  Future<bool> exists() async => await count() > 0;

  /// One page (from 1) of [size] rows, with the total of rows and of pages.
  Future<PageOf<T>> paginate(int page, [int size = 20]) async {
    page = page < 1 ? 1 : page;
    size = size < 1 ? 1 : size;
    final total = await count();
    _offset = (page - 1) * size;
    _limit = size;
    return PageOf(items: await getMany(), page: page, size: size, total: total, pages: (total + size - 1) ~/ size);
  }

  /// Sets [values] on every matching row; the number of rows changed.
  Future<int> update(Map<String, Object?> values) async {
    final rows = await _matching();
    for (final row in rows) {
      await table.putRow({...row, ...values});
    }
    return rows.length;
  }

  /// Deletes every matching row; the number of rows deleted.
  Future<int> delete() async {
    final b = await table.box;
    final rows = await _matching();
    for (final row in rows) {
      await b.delete(table.keyOf(row));
    }
    return rows.length;
  }
}

/// A comparison of `where` other than equality.
class Op {
  const Op(this.test);

  final bool Function(Object? value) test;
}

Op gt(Object value) => Op((x) => x != null && compareValues(x, value) > 0);

Op gte(Object value) => Op((x) => x != null && compareValues(x, value) >= 0);

Op lt(Object value) => Op((x) => x != null && compareValues(x, value) < 0);

Op lte(Object value) => Op((x) => x != null && compareValues(x, value) <= 0);

/// `ne(null)` is "not null"; a plain `null` in `where` is "is null".
Op ne(Object? value) => Op((x) => x != value);

/// SQL `LIKE`: `%` any text, `_` one character.
Op like(String pattern) => _like(pattern, caseSensitive: true);

Op ilike(String pattern) => _like(pattern, caseSensitive: false);

Op _like(String pattern, {required bool caseSensitive}) {
  final source = RegExp.escape(pattern).replaceAll('%', '.*').replaceAll('_', '.');
  final re = RegExp('^$source\$', caseSensitive: caseSensitive, dotAll: true);
  return Op((x) => x is String && re.hasMatch(x));
}

Op oneOf(List<Object?> values) => Op(values.contains);

Op between(Object low, Object high) =>
    Op((x) => x != null && compareValues(x, low) >= 0 && compareValues(x, high) <= 0);

/// Orders JSON values: numbers, texts (ISO dates among them), booleans; null first.
int compareValues(Object? a, Object? b) {
  if (a == null || b == null) return a == null ? (b == null ? 0 : -1) : 1;
  if (a is num && b is num) return a.compareTo(b);
  if (a is String && b is String) return a.compareTo(b);
  if (a is bool && b is bool) return (a ? 1 : 0) - (b ? 1 : 0);
  return '$a'.compareTo('$b');
}
