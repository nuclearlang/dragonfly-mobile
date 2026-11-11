/// Testing helpers for Dragonfly apps: start the app without network or devices, answer its HTTP
/// requests, replace any dependency with a fake (mocktail), pump screens and check `Either` results.
///
/// The `tests` kind of NuclearLang writes tests that use these helpers; they work in hand-written tests
/// too.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'src/core.dart';
import 'src/http/connection.dart';
import 'src/local/local.dart';
import 'src/network/network_manager.dart';
import 'src/session/session_manager.dart';

/// One request the app sent during a test.
class SentRequest {
  const SentRequest(this.method, this.uri, this.body);

  /// `GET`, `POST`...
  final String method;
  final Uri uri;
  final Object? body;

  /// The path without the base URL's host: `/api/character/1`.
  String get path => uri.path;

  Map<String, String> get query => uri.queryParameters;

  @override
  String toString() => '$method $uri';
}

/// How a fake connection answers: status code and JSON body.
typedef Responder = (int, Object?) Function(SentRequest request);

abstract final class DragonflyTest {
  /// Requests sent since the last [start].
  static final List<SentRequest> requests = [];

  static Responder _respond = _notFound;

  static (int, Object?) _notFound(SentRequest r) => (404, {'message': 'no fake answer for $r'});

  /// Empties the injector, the connections and the cache.
  static Future<void> reset() => Dragonfly.reset();

  /// Starts the app as `startDragonfly()` does, without network or devices: every `Http` connection of
  /// [config] answers with [respondWith] / [respond] (404 until then) and records [requests]; the session
  /// and the local database live in memory; `NetworkManager` reports [network]. [register] registers the app's classes
  /// (`registerDragonfly` of the generated code). The session never expires by inactivity in a test.
  static Future<void> start(
    AppConfig config, [
    Future<void> Function()? register,
    NetworkStatus network = const NetworkStatus(),
  ]) async {
    await Dragonfly.reset();
    requests.clear();
    _respond = _notFound;
    Local.memory = true;
    await Dragonfly.start(_TestConfig(config, network));
    await register?.call();
    // every Http connection (also those of the components' configs) answers without network
    for (final c in Dragonfly.connections.whereType<Http>()) {
      c.dio.httpClientAdapter = _FakeAdapter();
    }
  }

  /// Every request answers [json] with [status].
  static void respondWith(Object? json, {int status = 200}) => _respond = (_) => (status, json);

  /// Each request answers what [responder] returns.
  static void respond(Responder responder) => _respond = responder;

  /// Registers [fake] as the [T] every class receives (a mock, a repository without network).
  static void replace<T extends Object>(T fake) {
    final di = GetIt.instance;
    if (di.isRegistered<T>()) di.unregister<T>();
    di.registerSingleton<T>(fake);
  }

  /// Starts a session with [data] (for screens and use cases that need one).
  static Future<void> startSession<T extends Object>(
    T data, {
    String token = 'test',
    List<String> roles = const [],
    List<String> permissions = const [],
  }) => inject<SessionManager>().start<T>(data, token: token, roles: roles, permissions: permissions);
}

class _TestConfig extends AppConfig {
  _TestConfig(AppConfig app, NetworkStatus network)
    : connections = app.connections.whereType<Http>().toList(),
      globals = [
        for (final g in app.globals)
          if (g is NetworkManager)
            NetworkManager.fixed(network)
          // in memory, and without the inactivity timer (a widget test cannot end with a pending timer)
          else if (g is SessionManager)
            SessionManager(key: g.key, storage: _MemoryStorage())
          else
            g,
      ];

  @override
  final List<Connection> connections;

  @override
  final List<Global> globals;
}

/// Secure storage in memory: sessions of a test never touch the device.
class _MemoryStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _values.remove(key);
}

class _FakeAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    final sent = SentRequest(o.method, o.uri, o.data);
    DragonflyTest.requests.add(sent);
    final (status, data) = DragonflyTest._respond(sent);
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

extension DragonflyTester on WidgetTester {
  /// Shows [screen] inside a MaterialApp and waits until it is still. Network images do not load in
  /// widget tests: their errors are ignored.
  Future<void> pumpScreen(Widget screen, {bool settle = true}) async {
    final original = FlutterError.onError;
    FlutterError.onError = (d) => d.library == 'image resource service' ? null : original?.call(d);
    addTearDown(() => FlutterError.onError = original);
    await pumpWidget(MaterialApp(home: screen));
    if (settle) await pumpAndSettle();
  }

  /// Closes the shown screen and lets the timers it left run (a splash's minimum time and `onLoad`), so
  /// none is pending when the test ends. shortcut: waits one minute of test time; a longer timer still fails.
  Future<void> closeScreen() async {
    await pumpWidget(const SizedBox.shrink());
    await pump(const Duration(minutes: 1));
  }

  /// Shows the app with [router] (`buildRouter()` of the generated code) and waits.
  Future<void> pumpRouter(RouterConfig<Object> router) async {
    final original = FlutterError.onError;
    FlutterError.onError = (d) => d.library == 'image resource service' ? null : original?.call(d);
    addTearDown(() => FlutterError.onError = original);
    await pumpWidget(MaterialApp.router(routerConfig: router));
    await pumpAndSettle();
  }

  /// Taps the widget with [text] and waits.
  Future<void> tapText(String text) async {
    await tap(find.text(text));
    await pumpAndSettle();
  }

  /// Writes [text] in the text field that shows [label] (its label or hint).
  Future<void> enterTextIn(String label, String text) async {
    await enterText(find.widgetWithText(TextField, label), text);
    await pumpAndSettle();
  }
}

extension WhenFuture<T> on When<Future<T>> {
  /// The mocked async method returns [value]: `when(() => repo.find(1)).thenReturnAsync(Right(user))`.
  void thenReturnAsync(T value) => thenAnswer((_) async => value);
}

/// An `Either` that is `Right` (Ok).
const Matcher isOk = _EitherMatcher(true, null);

/// An `Either` that is `Left` (Err).
const Matcher isErr = _EitherMatcher(false, null);

/// A `Right` whose value matches [value] (a value or a matcher).
Matcher isOkWith(Object? value) => _EitherMatcher(true, wrapMatcher(value));

/// A `Left` whose error matches [error] (a value or a matcher).
Matcher isErrWith(Object? error) => _EitherMatcher(false, wrapMatcher(error));

class _EitherMatcher extends Matcher {
  const _EitherMatcher(this.right, this.inner);

  final bool right;
  final Matcher? inner;

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! Either) return false;
    if (item.isRight() != right) return false;
    final value = item.fold<Object?>((l) => l, (r) => r);
    return inner?.matches(value, matchState) ?? true;
  }

  @override
  Description describe(Description d) {
    d.add(right ? 'Ok (Right)' : 'Err (Left)');
    final m = inner;
    return m == null ? d : d.add(' with ').addDescriptionOf(m);
  }
}
