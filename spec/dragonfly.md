# `dragonfly` (Dart package)

> Dart and Flutter package (`packages/dragonfly`, publishable on pub.dev under the MIT license) with the
> classes an app needs between its screens and the backend that Flutter does not bring: http connections
> with cache and retries, repositories, state management, global events, session, ACL, network status,
> protected routes, logs, forms, dialogs, translations and test helpers.
>
> It is an independent package: it can be used by hand in any Flutter app. NuclearLang's
> [flutter](flutter.md) dialect generates code that uses it (its kinds `repository`, `statemanager`,
> `appConfig`, `tests`...), so in Nuclear its API is almost never written directly. README for pub.dev:
> [packages/dragonfly/README.md](../packages/dragonfly/README.md).

## 1. Dependencies

| Library | What for |
|---|---|
| `dio` | http requests |
| `bloc` / `flutter_bloc` | `StateManager` is a `Cubit` |
| `get_it` | the injector (`inject<T>()`) |
| `go_router` | `dragonflyRouter` |
| `connectivity_plus` | `NetworkManager` |
| `flutter_secure_storage` | `SessionManager` stores the session in the Keychain / Keystore; `Local` keeps the key of the local database there |
| `hive_ce` | `Local` / `LocalTable`: the local database (one box per table, on Android, iOS, Linux, macOS, Windows; IndexedDB on web), encrypted as `LocalDatabase` says |
| `json_annotation` | the generated models (json_serializable) |
| `flutter_localizations` (SDK) | `Translations.delegates`: the texts of Flutter's widgets |
| `path_provider`, `web` | `Translations` stores the remote dictionaries (files; `localStorage` on web) |
| `fpdart`, `mocktail`, `flutter_test` | `package:dragonfly/testing.dart` |

The package re-exports nothing of those libraries: each name is imported from its own, so no import is
left over.

## 2. Startup and injector

```dart
class AppSetup extends AppConfig {
  @override
  final List<Connection> connections = [Http(baseUrl: 'https://api.example.com/')];

  @override
  final List<Global> globals = [Events(), SessionManager(timeout: const Duration(minutes: 30)), NetworkManager()];
}

Future<void> main() async {
  await Dragonfly.start(AppSetup());
  Dragonfly.di.registerLazySingleton(CharacterRepository.new);
  runApp(const App());
}
```

| API | What it does |
|---|---|
| `AppConfig` / `ComponentConfig` | `connections` and `globals` of the app / of a component |
| `Dragonfly.start(config)` | registers the config, its connections and its global services, and starts them |
| `Dragonfly.addConfig(config)` | adds the connections and services of a component |
| `Dragonfly.di`, `inject<T>()` | the injector (GetIt) |
| `Dragonfly.connection<T>(name)`, `Dragonfly.connections` | the connections; `''` is the one without `connectionName`; two with the same name are an error |
| `Global` | an app-wide service: `register(di)`, `init()` (at startup), `dispose()` |
| `Dragonfly.reset()` | stops the services and empties the injector, connections, cache and the local database |

## 3. Network

| API | What it does |
|---|---|
| `Http(connectionName, baseUrl, connectTimeout, receiveTimeout, sendTimeout, headers, queryParameters, contentType, responseType, followRedirects, maxRedirects, persistentConnection, validateStatus, interceptors)` | a dio connection. `contentType` only when another one than dio's is wanted (JSON for maps and lists in requests with a body): a `Content-Type` on every request makes the browser send a CORS preflight before each GET |
| `WebSocket(connectionName, uri, headers, protocols, pingInterval, interceptors)` | `connect()` gives the messages, `send`, `close`; outside development, `wss://` |
| `HttpInterceptor` | override `onRequest(RequestOptions)`, `onResponse(Response)` or `onError(HttpError)`, without handlers |
| `SessionInterceptor`, `HttpLogInterceptor` | the session token (and ending the session on a 401); logs of each request |
| `EventInterceptor(header, events)` | a response (or an error) with the `header` header (`x-app-event`) publishes the event its value names in `events` |
| `HttpError` | `message`, `statusCode`, `data`, `headers`, `timeout`, `offline`, `transient` (timeout, no connection, 5xx). A `RepositoryError`, as `NotFound` of the local database |

### 3.1 `Repository`

```dart
class CharacterRepository extends Repository {
  CharacterRepository() : super(path: 'character');

  Future<Character> getOne(int id) =>
      send(HttpMethod.get, ':id', params: {'id': id}, decode: Decode.one(Character.fromJson));
}
```

`send(method, path, {params, pathParams, query, body, headers, cache, cacheName, retry, decode})`:

- The path is added to the connection's `baseUrl` and the repository's `path`; `:name` takes the value of
  `params` or `pathParams` (encoded).
- The `params` that do not go to the path go to the query of a GET or DELETE, or form the body of a POST,
  PUT or PATCH (a single value is the body as it is; a model is sent with its `toJson()`).
- `decode`: `Decode.one(Model.fromJson)`, `Decode.list(Model.fromJson)`, `Decode.value`, `Decode.values`,
  `Decode.none`.
- `cache: Cache(key, ttl)` (5-minute TTL by default): one entry per combination of arguments;
  `purgeCache(key)` deletes them; ending the session deletes the whole cache. The in-memory cache keeps up
  to 256 entries (`MemoryCache(maxEntries)`): when full, the expired ones go first and then the oldest.
- Retries: GET, PUT and DELETE retry transient failures twice, waiting 300 ms, 600 ms...; POST and PATCH
  only with `retry`, because repeating a write can duplicate it.
- A failure throws `HttpError`. `attempt(() => send(...), Right.new, (e) => Left(...))` turns a
  `RepositoryError` (`HttpError`, `NotFound`) into a value (an fpdart `Either`).
- `local: 'Repo.method'` saves the decoded value in the local database (§3.2) and
  `recall('Repo.method', path, {params, pathParams, query, decode})` answers it back for the same arguments
  (`NotFound` when that call never answered); `local<T>()` is the table of `T`.

### 3.2 Local database (`Local`, `LocalTable`)

```dart
class Character {
  static final LocalTable<Character> table = LocalTable<Character>('character', Character.fromJson, key: 'id');
}
Local.register(Character.table, component: 'characters'); // registerDragonfly
final alive = await Character.table.where({'status': 'Alive'}).orderBy('name').limit(20).getMany();
```

| API | What it does |
|---|---|
| `LocalDatabase({encrypted = true})` | `local` of `AppConfig` / `ComponentConfig`: how the tables are kept; `encrypted` is AES-256 with a key generated once in the secure storage (Keychain, Keystore, libsecret, DPAPI, WebCrypto); a component's config applies to the tables of its models |
| `LocalTable<T>(name, fromJson, {key, generated, created, updated})` | the table of a model: rows as JSON (`toJson`/`fromJson`) in the box `dragonfly_<name>` (`name` from `@entity` or the model's name in snake_case), by the JSON field `key`; `generated`: a null key gets the next number; `created`/`updated`: JSON fields the table stamps (ISO-8601) |
| `find(id)`, `findAll()`, `save(x)`, `saveAll(xs)`, `remove(id)`, `clear()` | CRUD; `find` is `Either<NotFound, T>`, `save` returns the row as saved |
| `where({...})`, `orderBy(field, desc:)`, `limit(n)`, `offset(n)` | a `LocalQuery<T>`; `where` takes equality or `gt`, `gte`, `lt`, `lte`, `ne`, `like`, `ilike`, `oneOf`, `between` (top-level functions); a plain `null` is "is null" |
| `getOne()`, `getMany()`, `count()`, `exists()`, `update({...})`, `delete()` | run the query (`count` ignores limit and offset) |
| `Local.register(table, {component})`, `Local.table<T>()`, `Local.tables` | the registry by model type (`table.component` picks its settings); a model without a table is a `StateError` that names the fix |
| `Local.configure(db, {component})`, `Local.settings([component])` | what `Dragonfly.start` / `addConfig` pass from the configs' `local`; `settings` is the component's, else the project's, else encrypted |
| `Local.store(call, value)`, `Local.recall(call)` | what `Repository.send(local:)` and `recall` use: the rows of a model or a list go to their table and the box `dragonfly_calls` remembers their keys under `call` (`name|url?query`) |
| `Local.start()`, `Local.open(name, {component})`, `Local.reset()`, `Local.memory`, `Local.storage`, `Local.keyName` | opens hive in the app's support folder (not on web); `open` applies the component's settings (the AES key, `dragonfly.local.key` in the secure storage, is made at the first encrypted box); `memory = true` (tests: `DragonflyTest.start`) keeps the boxes in memory, unencrypted; `reset` closes everything and forgets the settings |
| `NotFound` | a `RepositoryError`: `find`/`getOne`'s `Left`, thrown by `recall` |

Every table is loaded in memory by hive (`Box`): it is for what a phone shows, not for millions of rows.

## 4. State

`StateManager<S>`: a `Cubit<S>` that does not emit after it is closed (a closed screen gets no late
responses).

## 5. Global services

### 5.1 Events

| API | What it does |
|---|---|
| `Events.publish(event)` | publishes an `AppEvent`; in a background isolate of the app (where `Dragonfly.start` did not run) it sends it to the main one: the object, or its `eventName` and `toJson()` when it has them (the only way from another engine, like workmanager; `Events.decoder(name, fromJson)` reads it back) |
| `Events.subscribe<T>(handler, active)` → `Subscription` | `handler` gets each event of type `T`; with `active`, only while it returns `true`: meanwhile it keeps the last event and delivers it with `resume()`; `cancel()` ends it |
| `Events.last<T>()` | the last event of that type |
| `EventBuilder<T>(builder)`, `EventListener<T>(onEvent, child)` | rebuild with the last event / react to each one, only while their screen is the visible route; when shown again they get the last one that arrived |
| `EventsOnDemand` | mixin of a `State`: `onEvent<T>(handler)` with the same on-demand delivery |
| `SessionStarted<T>(data)`, `SessionEnded(expired)`, `ForceUpdate(minVersion)` | included events |

### 5.2 Session

| API | What it does |
|---|---|
| `SessionManager(timeout, storage, key)` | the session, stored encrypted (flutter_secure_storage); it ends after `timeout` without activity |
| `start<T>(data, token, roles, permissions, expiresAt)` | starts the session and publishes `SessionStarted<T>` |
| `get<T>()`, `session`, `active`, `touch()` | the data, the session (`Session`: `data`, `token`, `roles`, `permissions`, `expiresAt`, `values`), whether it is active; activity |
| `set(key, value)`, `value<T>(key)`, `remove(key)` | JSON values stored with the session |
| `destroy(expired)` | deletes it, empties the cache and publishes `SessionEnded` |
| `SessionManager.decoder<T>(fromJson)` | how to read the data of a session from a previous run (the generated code registers each model) |
| `GlobalEvents<T>(sessionStarted, sessionEnded, onSessionEnded)` | `sessionStarted(data)` with a session, `sessionEnded(event?)` without one; `onSessionEnded` once per end; on demand |
| `SessionInterceptor(header, scheme)` | `Authorization: Bearer <token>` on each request; a 401 ends the session, and an expired session is ended without sending its token |

### 5.3 ACL

| API | What it does |
|---|---|
| `Acl(inherits, permissions)` | global service: roles that inherit others (`{'admin': ['fan']}`) and the permissions of each role |
| `AclRule(roles, permissions, guards)` | a rule: one of the roles (or one that inherits it), all the permissions (of the session and its roles), each guard |
| `Acl.can(roles, permissions, guards)`, `Acl.allows(rule)` | whether the session passes; without a session only a rule without roles or permissions passes |
| `Acl.screens`, `Acl.canOpen(Screen)` | the rule of each screen (the router registers it) and whether the session opens it; computed once per session |
| `Guard` | `canActivate()` (`FutureOr<bool>`): an own check, registered in the injector. `Acl.check` and `Guards.verify` wait for an async one; `Acl.can`, `Acl.canOpen` and `Guards.check` are sync and throw with it |
| `AclBuilder(roles, permissions, guards, screen, child, fallback)` | `child` if the session passes the rule; changes with the session while its screen is visible |
| `Guards.check(internet, session, roles, permissions, guards)` | the message of the first check that fails, or `null` (use cases) |

### 5.4 Network

| API | What it does |
|---|---|
| `NetworkManager(probeHost, weakAfter, debounce)` | `status` (type: wifi, mobile, ethernet; quality: strong, weak, none), `online`, `check()`; it probes only when connectivity changes, and the first probe does not delay startup. On web it trusts what the browser says (it cannot resolve names). `NetworkManager.fixed(status)` for tests |
| `NetworkBuilder(builder)`, `NetworkWrapper(child, offline)` | rebuild with the network status / a notice over the whole app without internet |

## 6. Routes, logs, forms, popups and translations

| API | What it does |
|---|---|
| `dragonflyRouter(routes, initial, observers)` | a `GoRouter` with the screens; it updates when the session changes. When created it rejects a `forward` without a route (or with parameters) and an ACL rule without `denied` |
| `AppRoute<Screen>(path, build, args, loggedIn, acl, denied, shell, shellBuilder, tab, notFound, transition)` | a screen: `build` creates it from the address, `args` gives its parameters for the address; without a session it goes to `loggedIn`, without permission to `denied`; with `shell`, it is tab `tab` of a `StatefulShellRoute`; `notFound` is the error page; `transition` (`ScreenTransition`) how it comes in. `dragonflyRouter` nests a route in the one with the longest path that starts its own (never `/`), so back returns to it |
| `state.arg<T>(name)` | a route or query parameter as `T` (string, int, double, bool) |
| `context.goTo(screen)`, `context.pushTo<T>(screen)`, `context.goBack(result)` | navigate with the screen (its address comes from its route); `pushTo` returns what the screen gives back with `goBack` |
| `SplashScreen(next, child, minDuration, onLoad, onError)` | the first screen: `child` for at least `minDuration` (3 s) and until `onLoad` finishes; then `goTo(next)`. If `onLoad` fails, `onError(context, error, retry)`; without it, a log and `next`. A single timer, no polling |
| `Log.d/i/s/w/e` (or `debug/info/success/warn/error`), `Log.level`, `Log.sink`, `Log.colors`, `Log.console`, `Log.componentColors` | one block per log with the frame and level badge in the colors of Bootstrap's alerts (primary, info, success, warning, danger) and the breadcrumb `at` (`component › kind › Class.method · file:line`) in the component's color (`LogColor`, the same for the same name; `ComponentConfig.logColor` chooses it; Dragonfly in purple) and code colors; the time, the message, `data` as JSON, the error and the stack; only the stack line where an error happened blinks (`▶`). `Log.catchFlutterErrors(app:)` / `Log.formatError` / `Log.presentError`: Flutter exceptions with a double red frame, an ordered message and the stack in columns with the app's frames first in sight (Dart SDK hidden); a repeated error comes out in one line. In release only warn and error; `token`, `password`, `authorization`, `secret` and `cookie` are masked. `sink` gets a `LogEntry` |
| (debug, web) `globalThis.__dragonflyTextLayer()` | installed by `Dragonfly.start`: the visible texts with their box, color and weight as JSON (`t x y w h c b`); texts that something else covers (the page below, a dialog) are left out. Used by the Dragonfly Terminal device |
| `Rules.required/email/url/number/minLength/maxLength/min/max/pattern/matches(..., message)`, `Rules.asInt/asDouble` | the rules of a field (`Rule`: `(value, values) → message or null`); the message is a translation key or the text |
| `FormManager<F>(rules, initial, fromValues)` | the state of a form (Cubit of `FormValues`: `values`, `errors`, `errorOf`, `touched`, `checking`, `attempted`, `status`): `change`, `touch`, `submit(onValid)`, `reset`, `form`; `checkOf(field)` gives its remote validation (`FieldCheck`), with `debounce` (400 ms) and no stale responses |
| `DragonflyForm(manager, onSubmit, child)`, `FormTextField(name, ...)`, `FormCheckbox`, `FormInput<T>(name, builder)`, `FormSubmit(child)` | the form widgets, bound by the field name; each one rebuilds only when its own part changes |
| `Validators.required/email/minLength/maxLength/pattern/all` | the same messages for a plain `TextFormField` |
| `DragonflyDialog(child, header, footer, onClose, onCloseButton, onAccept, size, autoClose, color, icon)`, `.info/.success/.warning/.danger`, `.show(context)` | a header/body/footer dialog like a Bootstrap modal; the footer (Close, Accept) appears with `footer`, `onCloseButton` or `onAccept`; `show` returns `true` if it was accepted |
| `Popups.alert/confirm/show/loading/toast/snackbar`, `Popups.theme` (`PopupTheme(colors, icons, radius, widths)`), `PopupType`, `DialogSize` | popups with one call, with the color and icon of their type (from the app's theme) |
| `Translations(locales, fallback, path, remote)` (global) | JSON dictionaries per component in `assets/i18n/<locale>/<file>.json`: `Translations.tr(key, args)`, `'key'.tr(args)`, `use(locale)`, `locale`, `supportedLocales`, `delegates`, `refresh()` |
| `RemoteDictionaries(url, headers)` | dictionaries from a server (`manifest.json` + `<version>/<locale>/<file>.json`), stored by version |

## 7. Tests (`package:dragonfly/testing.dart`)

| API | What it does |
|---|---|
| `DragonflyTest.start(config, register, network)` | starts the app without network or device: each `Http` connection answers with a fake adapter (404 until the test says otherwise), the session lives in memory without expiry, `NetworkManager` reports `network` |
| `DragonflyTest.respondWith(json, status)`, `DragonflyTest.respond(f)` | what the connections answer |
| `DragonflyTest.requests` | the requests sent (`method`, `uri`, `path`, `query`, `body`) |
| `DragonflyTest.replace<T>(fake)` | replaces any class of the injector with a fake or a mock |
| `DragonflyTest.startSession(data, token, roles, permissions)`, `DragonflyTest.reset()` | |
| `tester.pumpScreen(screen)`, `tester.pumpRouter(router)`, `tester.tapText(text)`, `tester.enterTextIn(label, text)` | mount and use screens (network images are ignored) |
| `tester.closeScreen()` | closes the screen and lets its timers run (a splash's minimum time and `onLoad`), so none is left pending |
| `isOk`, `isErr`, `isOkWith(value)`, `isErrWith(error)` | `Either` matchers |
| `when(() => mock.method()).thenReturnAsync(value)` | the answer of an async method of a mocktail mock |

## 8. Publishing

```sh
cd packages/dragonfly
flutter analyze && flutter test
dart pub publish --dry-run
```

The `repository` field of `pubspec.yaml` (the URL of the public repository) is missing. When the public API
changes, its type definitions are regenerated (`tools/defs/generate.sh` → `defs/dart/dragonfly/<version>`),
used by the transpiler and the editor.
