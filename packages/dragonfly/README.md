# dragonfly

A lite clean architecture for Flutter: everything an app needs between the screens and the backend,
in small classes that work together.

- **Data**: `Http` connections over [dio](https://pub.dev/packages/dio) and `Repository`, which turns
  a method into a request: path parameters (`:id`), query, body, a response cache with TTL and purge,
  and retries with backoff (only for idempotent methods by default).
- **State**: `StateManager<S>`, a [bloc](https://pub.dev/packages/bloc) Cubit that never emits after
  it is closed.
- **Global services**: `Events` (typed publish/subscribe, delivered on demand: only the visible screen
  rebuilds; also from background isolates), `NetworkManager` (connection type and quality),
  `SessionManager` (typed session data in secure storage, inactivity timeout), `Acl` (inherited roles,
  permissions per role, guards).
- **Routing**: `dragonflyRouter`, a [go_router](https://pub.dev/packages/go_router) router: navigate with
  the screen (`context.goTo(DetailScreen(id: 7))`), path and query parameters, tabs, a not-found page,
  and screens that require a session or pass an ACL rule.
- **Forms**: form models with rules like zod or class-validator (`Rules.required`, `email`,
  `minLength`, `matches`...), a `FormManager` Cubit that validates on every change and runs remote checks
  with debounce, and `DragonflyForm`, `FormTextField`, `FormCheckbox`, `FormInput` and `FormSubmit`, bound
  to the fields by name.
- **Dialogs**: `DragonflyDialog` (header, body and footer like a Bootstrap modal; `info`, `success`,
  `warning`, `danger`; sizes; auto close), `Popups.alert/confirm/toast/snackbar/loading`, themed from the
  app's colors.
- **Translations**: one JSON dictionary per component and locale in `assets/i18n/<locale>/`,
  `'shop.home.title'.tr()`, no third-party package; optional remote dictionaries saved per version on
  every platform (files, or localStorage on the web).
- **Tools**: `Log` (`Log.d/i/s/w/e`: one block per log with a breadcrumb in a pastel color per component,
  masks tokens and passwords, quiet in release builds) and `DragonflyTest` to replace
  any dependency with a fake in tests.

Dragonfly is the runtime of NuclearLang apps for Flutter: the NuclearLang
transpiler writes the repositories, use cases and state managers that use these classes. It is also a
regular package that you can use by hand.

## Getting started

```yaml
dependencies:
  dragonfly: ^0.1.0
```

Configure the app once and start it before `runApp`:

```dart
import 'package:dragonfly/dragonfly.dart';
import 'package:flutter/material.dart';

class AppSetup extends AppConfig {
  @override
  final List<Connection> connections = [
    Http(baseUrl: 'https://rickandmortyapi.com/api/', interceptors: [const SessionInterceptor()]),
  ];

  @override
  final List<Global> globals = [Events(), SessionManager(), NetworkManager()];
}

Future<void> main() async {
  await Dragonfly.start(AppSetup());
  runApp(const MaterialApp(home: Scaffold(body: NetworkWrapper(child: Text('Hello')))));
}
```

## Repositories

```dart
class CharacterRepository extends Repository {
  CharacterRepository() : super(path: 'character');

  /// GET character/:id
  Future<Character> getOne(int id) =>
      send(HttpMethod.get, ':id', params: {'id': id}, decode: Decode.one(Character.fromJson));

  /// GET character?page=2, cached for 10 minutes for each page
  Future<List<Character>> getPage(int page) => send(
        HttpMethod.get,
        '',
        params: {'page': page},
        cache: const Cache(ttl: Duration(minutes: 10)),
        cacheName: 'CharacterRepository.getPage',
        decode: (json) => Decode.list(Character.fromJson)((json as Map)['results']),
      );
}
```

- A parameter used in the path (`:id`) goes there; the others go to the query of a GET or DELETE, or
  form the body of a POST, PUT or PATCH.
- A failed request throws `HttpError` (`message`, `statusCode`, `timeout`, `offline`). `attempt` turns it
  into a value, for example an `Either` of [fpdart](https://pub.dev/packages/fpdart):
  `attempt(() => getOne(id), Right.new, (e) => Left(e.message))`.
- GET, PUT and DELETE retry temporary failures twice; POST and PATCH only with `retry`.
- `purgeCache('CharacterRepository.getPage')` removes the cached pages; logging out clears the cache.

## Global events, network and session

```dart
Events.publish(const ForceUpdate(minVersion: '2.0.0'));

EventListener<ForceUpdate>(
  onEvent: (context, e) => Popups.alert(context, 'Update', 'Version ${e.minVersion} is required'),
  child: const HomeScreen(),
);

NetworkBuilder(builder: (context, status) => Text(status.online ? 'online' : 'offline'));

final session = inject<SessionManager>();
await session.start(user, token: user.token, roles: ['admin']); // publishes SessionStarted
GlobalEvents<User>(
  sessionStarted: (user) => Text('Hi ${user.name}'),
  sessionEnded: (_) => const LoginButton(),
);
await session.destroy(); // publishes SessionEnded

// the backend can publish events: `x-app-event: force_logout` publishes ForceLogout()
Http(baseUrl: 'https://api.example.com/', interceptors: [
  EventInterceptor(events: {'force_logout': () => const ForceLogout()}),
]);
```

## Access control and routing

```dart
final router = dragonflyRouter([
  AppRoute<HomeScreen>(path: '/', build: (s) => const HomeScreen()),
  AppRoute<DetailScreen>(
    path: '/characters/:id',
    build: (s) => DetailScreen(id: s.arg('id')),
    args: (screen) => {'id': screen.id},
  ),
  AppRoute<AdminScreen>(
    path: '/admin',
    build: (s) => const AdminScreen(),
    loggedIn: LoginScreen,
    acl: const AclRule(roles: ['admin'], guards: [OwnerGuard]),
    denied: DeniedScreen,
  ),
  AppRoute<LoginScreen>(path: '/login', build: (s) => const LoginScreen()),
  AppRoute<DeniedScreen>(path: '/denied', build: (s) => const DeniedScreen()),
]);

context.goTo(const DetailScreen(id: 7)); // /characters/7
AclBuilder(screen: AdminScreen, child: const AdminButton());
```

Roles inherit roles and get permissions with `Acl(inherits: {'admin': ['editor']}, permissions: {...})`
in the globals of the app config.

## Tests

```dart
import 'package:dragonfly/testing.dart';

setUp(() async {
  await DragonflyTest.reset();
  DragonflyTest.replace<CharacterRepository>(FakeCharacterRepository());
});
```

## License

MIT
