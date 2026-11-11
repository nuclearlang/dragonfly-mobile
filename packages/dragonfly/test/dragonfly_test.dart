import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dragonfly/dragonfly.dart';
import 'package:dragonfly/testing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with [respond] and records what was asked.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.respond);

  final (int, Object?) Function(RequestOptions o) respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    requests.add(o);
    final (status, data) = respond(o);
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class Item {
  Item(this.id, this.name);

  factory Item.fromJson(Map<String, dynamic> j) => Item(j['id'] as int, j['name'] as String);

  final int id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class ItemRepository extends Repository {
  ItemRepository() : super(path: 'items');

  Future<Item> one(int id) => send(HttpMethod.get, ':id', params: {'id': id}, decode: Decode.one(Item.fromJson));

  Future<List<Item>> page(int page) => send(
    HttpMethod.get,
    '',
    params: {'page': page},
    cache: const Cache(),
    cacheName: 'ItemRepository.page',
    decode: Decode.list(Item.fromJson),
  );

  Future<Item> save(Item item) => send(HttpMethod.post, '', params: {'item': item}, decode: Decode.one(Item.fromJson));
}

Future<FakeAdapter> setUpHttp((int, Object?) Function(RequestOptions o) respond) async {
  final http = Http(baseUrl: 'https://api.test/v1/');
  final adapter = FakeAdapter(respond);
  http.dio.httpClientAdapter = adapter;
  await Dragonfly.start(_Config([http]));
  return adapter;
}

class _Config extends AppConfig {
  const _Config(this.connections);

  @override
  final List<Connection> connections;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(DragonflyTest.reset);

  group('repository', () {
    test('path params, query and decoding', () async {
      final a = await setUpHttp((o) => (200, {'id': 7, 'name': 'Rick'}));
      final item = await ItemRepository().one(7);
      expect(item.name, 'Rick');
      expect(a.requests.single.uri.toString(), 'https://api.test/v1/items/7');
    });

    test('params not in the path go to the query of a GET and to the body of a POST', () async {
      final a = await setUpHttp((o) => (200, o.method == 'GET' ? [] : {'id': 1, 'name': 'Morty'}));
      await ItemRepository().page(2);
      expect(a.requests.last.uri.toString(), 'https://api.test/v1/items?page=2');
      await ItemRepository().save(Item(1, 'Morty'));
      expect(a.requests.last.method, 'POST');
      expect(a.requests.last.data, {'id': 1, 'name': 'Morty'});
    });

    test('the cache drops expired entries, then the oldest, past its size', () {
      final c = MemoryCache(maxEntries: 2)
        ..write('a', 1, const Duration(minutes: 1))
        ..write('b', 2, const Duration(seconds: -1))
        ..write('c', 3, const Duration(minutes: 1));
      expect([c.read('a')?.value, c.read('b'), c.read('c')?.value], [1, null, 3]);
      c.write('d', 4, const Duration(minutes: 1));
      expect([c.read('a'), c.read('c')?.value, c.read('d')?.value], [null, 3, 4]);
    });

    test('cached responses are reused per arguments and purged by key', () async {
      final a = await setUpHttp(
        (o) => (
          200,
          [
            {'id': 1, 'name': 'a'},
          ],
        ),
      );
      final repo = ItemRepository();
      await repo.page(1);
      await repo.page(1);
      await repo.page(2);
      expect(a.requests.length, 2);
      repo.purgeCache('ItemRepository.page');
      await repo.page(1);
      expect(a.requests.length, 3);
    });

    test('GET retries a server error; POST does not', () async {
      var calls = 0;
      final a = await setUpHttp((o) => (++calls < 3 ? 503 : 200, {'id': 1, 'name': 'ok'}));
      expect((await ItemRepository().one(1)).name, 'ok');
      expect(a.requests.length, 3);
      calls = 0;
      await expectLater(ItemRepository().save(Item(1, 'x')), throwsA(isA<HttpError>()));
      expect(a.requests.length, 4);
    });

    test('a client error is not retried and keeps its status', () async {
      await setUpHttp((o) => (404, {'error': 'not found'}));
      final e = await ItemRepository().one(1).then<HttpError?>((_) => null, onError: (Object e) => e as HttpError);
      expect(e!.statusCode, 404);
      expect(e.transient, isFalse);
    });

    test('a path parameter without a value is an error', () {
      expect(() => Repository.buildPath('items/:id', {}), throwsArgumentError);
    });

    test('attempt turns an HttpError into the error value', () async {
      await setUpHttp((o) => (500, {}));
      final r = await ItemRepository().attempt(
        () => ItemRepository().save(Item(1, 'x')),
        (v) => 'ok',
        (e) => 'err ${(e as HttpError).statusCode}',
      );
      expect(r, 'err 500');
    });

    test('backoff grows', () {
      expect(Repository.backoff(0), const Duration(milliseconds: 300));
      expect(Repository.backoff(2), const Duration(milliseconds: 1200));
    });
  });

  group('connections', () {
    test('two connections with the same name are rejected', () async {
      final c = [Http(baseUrl: 'a'), Http(baseUrl: 'b')];
      expect(Dragonfly.start(_Config(c)), throwsStateError);
    });

    test('a missing connection names the known ones', () async {
      await Dragonfly.start(_Config([Http(baseUrl: 'a', connectionName: 'main')]));
      expect(() => Dragonfly.connection<Http>('other'), throwsA(predicate((e) => '$e'.contains('main'))));
    });
  });

  group('forms and logs', () {
    test('validators', () {
      final v = Validators.all([Validators.required(), Validators.email()]);
      expect(v(''), 'Required');
      expect(v('nope'), 'Invalid email');
      expect(v('a@b.co'), isNull);
      expect(Validators.minLength(3)('ab'), 'At least 3 characters');
    });

    test('logs mask sensitive values', () {
      expect(
        Log.mask({
          'user': 'ana',
          'accessToken': 'x',
          'nested': {'Password': 'y'},
        }),
        {
          'user': 'ana',
          'accessToken': '***',
          'nested': {'Password': '***'},
        },
      );
    });

    test('logs show the breadcrumb, the data and the .nuc line', () {
      final entry = LogEntry(
        LogLevel.info,
        'page loaded',
        data: Log.mask({'page': 2, 'token': 'x'}),
        at: 'characters › repository › CharacterRepository.getPage · components/characters/data/r.nuc:12',
        time: DateTime(2026, 1, 1, 9, 5, 7, 42),
      );
      expect(entry.component, 'characters');
      final lines = Log.format(entry).split('\n');
      expect(lines[0], startsWith('┏━  INFO      characters › repository › CharacterRepository.getPage  09:05:07.042 ━'));
      expect(lines.sublist(1, 3), ['┃  page loaded', '┃  data: {"page":2,"token":"***"}']);
      expect(lines[3], startsWith('┗━ components/characters/data/r.nuc:12 ━'));
      expect([lines[0].length, lines[3].length], [Log.width, Log.width]);
      // the same component always gets the same color, unless its config chooses one
      expect(Log.colorOf('characters'), Log.colorOf('characters'));
      Log.componentColors['characters'] = LogColor.rose;
      expect(Log.colorOf('characters'), LogColor.rose);
      Log.componentColors.clear();
    });

    test('Flutter errors: the message, then the stack with the app first in sight', () {
      Log.appPackage = 'app';
      final details = FlutterErrorDetails(
        exception: 'Assertion failed:\nfile:///f/packages/flutter/lib/src/services/raw_keyboard.dart:863:7\nkeys is empty',
        library: 'services library',
        stack: StackTrace.fromString(
          'dart-sdk/lib/_internal/js_dev_runtime/private/ddc_runtime/errors.dart 274:3  throw_\n'
          'package:flutter/src/services/raw_keyboard.dart 863:49  handleRawKeyEvent\n'
          '#2      HomeScreen.build (package:app/components/home/home_screen.dart:42:7)',
        ),
      );
      final lines = Log.formatError(details).split('\n');
      expect(lines[1], startsWith('║  ✖  EXCEPTION  ·  services library'));
      expect(lines, contains('║  at flutter/src/services/raw_keyboard.dart:863:7'));
      expect(lines, contains('║     · 1 Dart SDK frame'));
      expect(lines.firstWhere((l) => l.contains('▶')), startsWith('║  ▶ app       components/home/home_screen.dart:42'));
      expect('\x1B[5m'.allMatches(Log.formatError(details, colors: true)).length, 1);
    });

    test('only the exact place of an error blinks', () {
      final text = Log.format(
        LogEntry(
          LogLevel.error,
          'page failed',
          error: 'timeout',
          stackTrace: StackTrace.fromString(
            '#0      Http.send (package:dragonfly/src/http/http.dart:10:5)\n'
            '#1      GetPageUseCase.exec (package:app/components/x.dart:21:5)',
          ),
        ),
        colors: true,
      );
      expect('\x1B[5m'.allMatches(text).length, 1);
      for (final l in LogLevel.values) {
        expect(Log.format(LogEntry(l, 'ok'), colors: true), isNot(contains('\x1B[5m')));
      }
      // VS Code's debug console reads `ESC[1;38;5;42m` as blink + background: never mixed
      expect(text, isNot(contains(RegExp(r'\x1B\[1;'))));
      expect(text, contains('\x1B[1m\x1B[5m\x1B[38;5;203m▶ #1      GetPageUseCase.exec'));
    });
  });

  test('a fake replaces a registered object', () {
    DragonflyTest.replace<ItemRepository>(ItemRepository());
    expect(inject<ItemRepository>(), isA<ItemRepository>());
  });
}
