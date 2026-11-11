import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dragonfly/dragonfly.dart';
import 'package:dragonfly/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class Auth {
  const Auth(this.name);

  factory Auth.fromJson(Map<String, dynamic> j) => Auth(j['name'] as String);

  final String name;

  Map<String, dynamic> toJson() => {'name': name};
}

class ForceLogout extends AppEvent {
  const ForceLogout();
}

class Ping extends AppEvent {
  const Ping(this.n);

  final int n;
}

/// As the `event` kind writes it: a name and JSON, so another engine can publish it.
class Synced extends AppEvent {
  const Synced(this.items);

  factory Synced.fromJson(Map<String, dynamic> json) => Synced((json['items'] as List).cast<String>());

  final List<String> items;

  @override
  String get eventName => 'Synced';

  @override
  Map<String, dynamic> toJson() => {'items': items};
}

class OwnerGuard extends Guard {
  OwnerGuard(this.sessions);

  final SessionManager sessions;

  @override
  bool canActivate() => sessions.active && sessions.get<Auth>().name == 'ana';
}

class SlowGuard extends Guard {
  SlowGuard(this.sessions);

  final SessionManager sessions;

  @override
  Future<bool> canActivate() async => sessions.active && sessions.get<Auth>().name == 'ana';
}

class Config extends AppConfig {
  Config([this.globals = const []]);

  @override
  final List<Global> globals;
}

Future<SessionManager> startSessions({Acl? acl}) async {
  final sessions = SessionManager();
  await Dragonfly.start(Config([Events(), sessions, ?acl]));
  return sessions;
}

/// Answers every request with [headers].
class HeaderAdapter implements HttpClientAdapter {
  HeaderAdapter(this.status, this.headers);

  final int status;
  final Map<String, List<String>> headers;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async =>
      ResponseBody.fromString(
        jsonEncode({}),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          ...headers,
        },
      );

  @override
  void close({bool force = false}) {}
}

// screens of the router tests
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const Text('home'),
        TextButton(
          onPressed: () => context.goTo(const Detail(id: 7, tab: 'info')),
          child: const Text('detail'),
        ),
        TextButton(
          onPressed: () async {
            final picked = await context.pushTo<String>(const Picker());
            if (context.mounted) Popups.alert(context, 'Picked', 'picked $picked');
          },
          child: const Text('pick'),
        ),
        TextButton(onPressed: () => context.goTo(const Private()), child: const Text('private')),
        TextButton(onPressed: () => context.goTo(const Admin()), child: const Text('admin')),
      ],
    ),
  );
}

class Detail extends StatelessWidget {
  const Detail({super.key, required this.id, this.tab});

  final int id;
  final String? tab;

  @override
  Widget build(BuildContext context) => Text('detail $id $tab');
}

class Picker extends StatelessWidget {
  const Picker({super.key});

  @override
  Widget build(BuildContext context) => TextButton(onPressed: () => context.goBack('blue'), child: const Text('blue'));
}

class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) => const Text('login');
}

class Private extends StatelessWidget {
  const Private({super.key});

  @override
  Widget build(BuildContext context) => const Text('private');
}

class Admin extends StatelessWidget {
  const Admin({super.key});

  @override
  Widget build(BuildContext context) => const Text('admin');
}

class Denied extends StatelessWidget {
  const Denied({super.key});

  @override
  Widget build(BuildContext context) => const Text('denied');
}

class Vault extends StatelessWidget {
  const Vault({super.key});

  @override
  Widget build(BuildContext context) => const Text('vault');
}

class Missing extends StatelessWidget {
  const Missing({super.key});

  @override
  Widget build(BuildContext context) => const Text('not found');
}

class Tabs extends StatelessWidget {
  const Tabs({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(child: shell),
      Text('tab ${shell.currentIndex}'),
      TextButton(onPressed: () => shell.goBranch(1), child: const Text('second')),
    ],
  );
}

GoRouter router({String initial = '/'}) => dragonflyRouter(initial: initial, [
  AppRoute<Home>(path: '/', build: (s) => const Home()),
  AppRoute<Detail>(
    path: '/detail/:id',
    build: (s) => Detail(id: s.arg('id'), tab: s.arg('tab')),
    args: (w) => {'id': w.id, 'tab': w.tab},
  ),
  AppRoute<Picker>(path: '/picker', build: (s) => const Picker()),
  AppRoute<Login>(path: '/login', build: (s) => const Login()),
  AppRoute<Denied>(path: '/denied', build: (s) => const Denied()),
  AppRoute<Private>(path: '/private', build: (s) => const Private(), loggedIn: Login),
  AppRoute<Admin>(
    path: '/admin',
    build: (s) => const Admin(),
    loggedIn: Login,
    acl: const AclRule(roles: ['admin']),
    denied: Denied,
  ),
  AppRoute<Missing>(build: (s) => const Missing(), notFound: true),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await Dragonfly.reset();
  });

  group('events', () {
    test('publish and subscribe are typed; cancel stops a subscription', () async {
      await Dragonfly.start(Config([Events()]));
      final got = <int>[];
      final sub = Events.subscribe<Ping>((e) => got.add(e.n));
      Events.publish(const ForceLogout());
      Events.publish(const Ping(1));
      sub.cancel();
      Events.publish(const Ping(2));
      expect(got, [1]);
      expect(Events.last<Ping>()?.n, 2);
    });

    test('an inactive subscriber keeps only the last event and gets it on resume', () async {
      await Dragonfly.start(Config([Events()]));
      var active = false;
      final got = <int>[];
      final sub = Events.subscribe<Ping>((e) => got.add(e.n), active: () => active);
      Events.publish(const Ping(1));
      Events.publish(const Ping(2));
      expect(got, isEmpty);
      active = true;
      sub.resume();
      sub.resume();
      expect(got, [2]);
    });

    test('an event published in a background isolate reaches the main one', () async {
      await Dragonfly.start(Config([Events()]));
      final got = <int>[];
      Events.subscribe<Ping>((e) => got.add(e.n));
      await Isolate.run(() => Events.publish(const Ping(9)));
      await pumpEventQueue();
      expect(got, [9]);
    });

    test('an event with a name travels as JSON and is read back by its decoder', () async {
      await Dragonfly.start(Config([Events()]));
      Events.decoder('Synced', Synced.fromJson);
      final got = <List<String>>[];
      Events.subscribe<Synced>((e) => got.add(e.items));
      await Isolate.run(() => Events.publish(const Synced(['a', 'b'])));
      await pumpEventQueue();
      expect(got, [
        ['a', 'b'],
      ]);
    });

    test('a backend header publishes the event it names', () async {
      final http = Http(
        baseUrl: 'https://api.test/',
        interceptors: [
          EventInterceptor(events: {'force_logout': () => const ForceLogout()}),
        ],
      );
      await Dragonfly.start(_Http([http]));
      final got = <AppEvent>[];
      Events.subscribe<ForceLogout>(got.add);
      http.dio.httpClientAdapter = HeaderAdapter(200, {
        'x-app-event': ['force_logout'],
      });
      await http.dio.get<Object?>('a');
      http.dio.httpClientAdapter = HeaderAdapter(409, {
        'x-app-event': ['force_logout'],
      });
      await expectLater(http.dio.get<Object?>('b'), throwsA(isA<DioException>()));
      http.dio.httpClientAdapter = HeaderAdapter(200, {
        'x-app-event': ['unknown'],
      });
      await http.dio.get<Object?>('c');
      expect(got, hasLength(2));
    });

    testWidgets('a hidden screen does not rebuild; it gets the last event when it is visible again', (tester) async {
      await Dragonfly.start(Config([Events()]));
      final builds = <String>[];
      Widget screen(String name) => EventBuilder<Ping>(
        builder: (context, e) {
          builds.add('$name ${e?.n}');
          return Text('$name ${e?.n}');
        },
      );
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(navigatorKey: nav, home: screen('home')));
      nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => screen('cards')));
      await tester.pumpAndSettle();
      builds.clear();
      Events.publish(const Ping(1));
      await tester.pump();
      expect(builds, ['cards 1']);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('home 1'), findsOneWidget);
    });
  });

  group('session', () {
    test('an expired session sends no token and ends', () async {
      final sessions = await startSessions();
      await sessions.start('ana', token: 't1', expiresAt: DateTime.now().subtract(const Duration(seconds: 1)));
      final request = RequestOptions();
      await const SessionInterceptor().onRequest(request);
      expect(request.headers['Authorization'], isNull);
      expect(sessions.session, isNull);
    });

    test('start, get, values and destroy; events and cache', () async {
      final sessions = await startSessions();
      final events = <AppEvent>[];
      Events.subscribe<SessionStarted>(events.add);
      Events.subscribe<SessionEnded>(events.add);
      await sessions.start(const Auth('ana'), token: 't', roles: ['fan']);
      expect(sessions.active, isTrue);
      expect(sessions.get<Auth>().name, 'ana');
      await sessions.set('theme', 'dark');
      expect(sessions.value<String>('theme'), 'dark');
      await sessions.remove('theme');
      expect(sessions.value<String>('theme'), isNull);
      Dragonfly.cache.write('k', 1, const Duration(minutes: 1));
      await sessions.destroy();
      expect(sessions.active, isFalse);
      expect(Dragonfly.cache.length, 0);
      expect(events.first, isA<SessionStarted<Auth>>());
      expect(events.last, isA<SessionEnded>());
    });

    test('the session of a previous run is restored with its model', () async {
      SessionManager.decoder<Auth>(Auth.fromJson);
      final first = await startSessions();
      await first.start(const Auth('ana'), roles: ['fan']);
      await first.set('lang', 'es');
      await Dragonfly.reset();
      final second = await startSessions();
      expect(second.get<Auth>().name, 'ana');
      expect(second.session!.roles, ['fan']);
      expect(second.value<String>('lang'), 'es');
    });

    test('an expired session is not restored', () async {
      final first = await startSessions();
      await first.start('ana', expiresAt: DateTime.now().subtract(const Duration(minutes: 1)));
      await Dragonfly.reset();
      expect((await startSessions()).active, isFalse);
    });

    test('the session ends after the inactivity timeout', () async {
      final sessions = SessionManager(timeout: const Duration(milliseconds: 20));
      await Dragonfly.start(Config([Events(), sessions]));
      await sessions.start('ana');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(sessions.active, isFalse);
    });

    testWidgets('GlobalEvents shows the session data and reacts when it ends', (tester) async {
      final sessions = await startSessions();
      final ended = <SessionEnded>[];
      await tester.pumpWidget(
        MaterialApp(
          home: GlobalEvents<Auth>(
            sessionStarted: (auth) => Text('hi ${auth.name}'),
            sessionEnded: (e) => Text(e == null ? 'guest' : 'bye'),
            onSessionEnded: ended.add,
          ),
        ),
      );
      expect(find.text('guest'), findsOneWidget);
      await tester.runAsync(() => sessions.start(const Auth('ana')));
      await tester.pump();
      expect(find.text('hi ana'), findsOneWidget);
      await tester.runAsync(() => sessions.destroy(expired: true));
      await tester.pump();
      expect(find.text('bye'), findsOneWidget);
      expect(ended.single.expired, isTrue);
    });
  });

  group('acl', () {
    test('roles inherit roles and permissions; guards come from the injector', () async {
      final sessions = await startSessions(
        acl: Acl(
          inherits: {
            'admin': ['editor'],
            'editor': ['fan'],
          },
          permissions: {
            'editor': ['invoices.edit'],
          },
        ),
      );
      Dragonfly.di.registerLazySingleton(() => OwnerGuard(inject<SessionManager>()));
      expect(Acl.can(roles: ['fan']), isFalse);
      expect(Acl.can(guards: [OwnerGuard]), isFalse);
      await sessions.start(const Auth('ana'), roles: ['admin'], permissions: ['reports.read']);
      expect(Acl.can(roles: ['fan']), isTrue);
      expect(Acl.can(permissions: ['invoices.edit', 'reports.read']), isTrue);
      expect(Acl.can(permissions: ['invoices.delete']), isFalse);
      expect(Acl.can(guards: [OwnerGuard]), isTrue);
      expect(Guards.check(roles: ['nobody']), 'Access denied');
      await sessions.start(const Auth('bob'), roles: ['fan']);
      expect(Acl.can(roles: ['editor']), isFalse);
      expect(Acl.can(guards: [OwnerGuard]), isFalse);
    });

    test('an async guard is awaited by check and verify; the sync can refuses it', () async {
      final sessions = await startSessions();
      Dragonfly.di.registerLazySingleton(() => SlowGuard(inject<SessionManager>()));
      expect(await Acl.check(guards: [SlowGuard]), isFalse);
      await sessions.start(const Auth('ana'));
      expect(await Acl.check(guards: [SlowGuard]), isTrue);
      expect(await Guards.verify(guards: [SlowGuard]), isNull);
      expect(() => Acl.can(guards: [SlowGuard]), throwsStateError);
      await sessions.start(const Auth('bob'));
      expect(await Guards.verify(guards: [SlowGuard]), 'Access denied');
    });
  });

  group('router', () {
    testWidgets('path and query parameters, goTo, pushTo and goBack', (tester) async {
      await startSessions();
      await tester.pumpRouter(router());
      await tester.tapText('detail');
      expect(find.text('detail 7 info'), findsOneWidget);
      await tester.pumpRouter(router(initial: '/detail/3?tab=bio'));
      expect(find.text('detail 3 bio'), findsOneWidget);
      await tester.pumpRouter(router());
      await tester.tapText('pick');
      await tester.tapText('blue');
      expect(find.text('picked blue'), findsOneWidget);
    });

    testWidgets('loggedIn and ACL send to their forward screens', (tester) async {
      final sessions = await startSessions();
      await tester.pumpRouter(router());
      await tester.tapText('private');
      expect(find.text('login'), findsOneWidget);
      await tester.pumpRouter(router(initial: '/admin'));
      expect(find.text('login'), findsOneWidget);
      await tester.runAsync(() => sessions.start('ana', roles: ['fan']));
      await tester.pumpRouter(router(initial: '/admin'));
      expect(find.text('denied'), findsOneWidget);
      await tester.runAsync(() => sessions.start('ana', roles: ['admin']));
      await tester.pumpRouter(router(initial: '/admin'));
      expect(find.text('admin'), findsOneWidget);
      expect(Acl.canOpen(Admin), isTrue);
    });

    testWidgets('the router waits for an async guard', (tester) async {
      final sessions = await startSessions();
      Dragonfly.di.registerLazySingleton(() => SlowGuard(inject<SessionManager>()));
      GoRouter vault() => dragonflyRouter(initial: '/vault', [
        AppRoute<Denied>(path: '/denied', build: (s) => const Denied()),
        AppRoute<Vault>(
          path: '/vault',
          build: (s) => const Vault(),
          acl: const AclRule(guards: [SlowGuard]),
          denied: Denied,
        ),
      ]);
      await tester.pumpRouter(vault());
      expect(find.text('denied'), findsOneWidget);
      await tester.runAsync(() => sessions.start(const Auth('ana')));
      await tester.pumpRouter(vault());
      expect(find.text('vault'), findsOneWidget);
    });

    testWidgets('a route inside another stacks on it: back returns to the parent', (tester) async {
      await startSessions();
      await tester.pumpRouter(
        dragonflyRouter(initial: '/vault/detail/4', [
          AppRoute<Home>(path: '/', build: (s) => const Home()),
          AppRoute<Vault>(path: '/vault', build: (s) => const Vault(), transition: ScreenTransition.fade),
          AppRoute<Detail>(
            path: '/vault/detail/:id',
            build: (s) => Detail(id: s.arg('id'), tab: s.arg('tab')),
            args: (w) => {'id': w.id, 'tab': w.tab},
            transition: ScreenTransition.none,
          ),
        ]),
      );
      expect(find.text('detail 4 null'), findsOneWidget);
      final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
      expect(nav.canPop(), isTrue);
      nav.pop();
      await tester.pumpAndSettle();
      expect(find.text('vault'), findsOneWidget);
    });

    testWidgets('an unknown location shows the notFound screen', (tester) async {
      await startSessions();
      await tester.pumpRouter(router(initial: '/nowhere'));
      expect(find.text('not found'), findsOneWidget);
    });

    testWidgets('screens with a shell are its tabs', (tester) async {
      await startSessions();
      Widget tabs(StatefulNavigationShell s) => Tabs(shell: s);
      await tester.pumpRouter(
        dragonflyRouter([
          AppRoute<Home>(path: '/', build: (s) => const Home(), shell: Tabs, shellBuilder: tabs),
          AppRoute<Login>(path: '/second', build: (s) => const Login(), shell: Tabs, shellBuilder: tabs, tab: 1),
        ]),
      );
      expect(find.text('tab 0'), findsOneWidget);
      await tester.tapText('second');
      expect(find.text('tab 1'), findsOneWidget);
      expect(find.text('login'), findsOneWidget);
    });

    test('a forward screen without a route and an ACL rule without forward are rejected', () {
      expect(
        () => dragonflyRouter([AppRoute<Private>(path: '/p', build: (s) => const Private(), loggedIn: Login)]),
        throwsArgumentError,
      );
      expect(
        () => dragonflyRouter([
          AppRoute<Admin>(
            path: '/a',
            build: (s) => const Admin(),
            acl: const AclRule(roles: ['admin']),
          ),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('splash', () {
    GoRouter splash(Widget s) => dragonflyRouter([
      AppRoute<SplashScreen>(path: '/', build: (_) => s as SplashScreen),
      AppRoute<Login>(path: '/login', build: (_) => const Login()),
    ]);

    testWidgets('stays the minimum time, then waits for onLoad and goes to next', (tester) async {
      final load = Completer<void>();
      var loads = 0;
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: splash(
            SplashScreen(
              next: const Login(),
              minDuration: const Duration(seconds: 1),
              onLoad: () {
                loads++;
                return load.future;
              },
              child: const Text('logo'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('logo'), findsOneWidget); // onLoad is still running
      load.complete();
      await tester.pumpAndSettle();
      expect(find.text('login'), findsOneWidget);
      expect(loads, 1);
    });

    testWidgets('a fast onLoad still waits for the minimum time', (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: splash(
            SplashScreen(next: const Login(), onLoad: () async {}, child: const Text('logo')),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 2900));
      expect(find.text('logo'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('login'), findsOneWidget);
    });

    testWidgets('a failed onLoad shows onError and retry runs it again', (tester) async {
      var fail = true;
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: splash(
            SplashScreen(
              next: const Login(),
              minDuration: Duration.zero,
              onLoad: () async {
                if (fail) throw StateError('backend down');
              },
              onError: (c, e, retry) => TextButton(onPressed: retry, child: const Text('retry')),
              child: const Text('logo'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      fail = false;
      await tester.tapText('retry');
      expect(find.text('login'), findsOneWidget);
    });
  });

}

class _Http extends AppConfig {
  const _Http(this.connections);

  @override
  final List<Connection> connections;

  @override
  List<Global> get globals => [Events()];
}
