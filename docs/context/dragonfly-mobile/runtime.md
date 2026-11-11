---
layer: L3
component: dragonfly-mobile
read-when: you change or use a service of the Dart package packages/dragonfly
---

# The `dragonfly` Dart package (`spec/dragonfly.md`)

`(cd packages/dragonfly && flutter test && flutter analyze)` — 64 tests. `Global.init/dispose`.

- **Local database** (ADR-0096, `src/local/local.dart`, `spec/dragonfly.md` §3.2): `Local` (hive_ce boxes, the same on
  every platform; `LocalDatabase(encrypted)` from the configs' `local`, per component (`configure`/`settings`, the
  table's `component`), AES key in the secure storage made at the first encrypted box, `memory` for tests,
  `store`/`recall` with the calls box), `LocalTable<T>` (CRUD + the
  backend's query builder over JSON rows; `putRow` stamps `created`/`updated` and gives `generated` keys),
  `LocalQuery<T>`, the operators `gt`...`between` (no `isNull`: it clashes with the `flutter_test` matcher; a plain
  `null` in `where`), `NotFound` (a `RepositoryError`, like `HttpError`; `attempt` catches both). `Repository.send(local:)`,
  `recall`, `target`, `local<T>()`, `saveLocal`. `Dragonfly.reset` closes it; `DragonflyTest.start` sets `memory`.

- **Events** (ADR-0052): `Events.publish/subscribe`. On demand: the visible screen gets the event at once;
  hidden ones, the last of each type when shown again. `component` with `@on` always receive. A background
  isolate publishes to the main one (not on web: no `ReceivePort`/`IsolateNameServer` with `kIsWeb`); an
  `event` has `eventName` + `toJson`/`fromJson`, so from another engine (workmanager) it travels as JSON text
  and `Events.decoder` (registered in `registerModels`) reads it back. The
  backend publishes with header `x-app-event` (`EventInterceptor`). Widgets `EventBuilder`, `EventListener`,
  `GlobalEvents<T>`, mixin `EventsOnDemand`.
- **Session** (ADR-0054): `session.start(data, token, roles, permissions, expiresAt)`, `get<T>()`,
  `set/value/remove`, `destroy()`; flutter_secure_storage, survives restarts. `start` publishes
  `SessionStarted<T>`, `destroy` publishes `SessionEnded` and purges the cache. `SessionInterceptor` adds the
  token, ends the session on a 401 and never sends an expired token.
- **ACL** (ADR-0056): Phalcon style (`Acl(inherits, permissions)`, deny by default) + NestJS guards. The access
  map per screen is computed once per session. `Guard`/`Guards`. `canActivate` is `FutureOr<bool>`: the
  router (async `redirect` only then), `AclBuilder`, `Acl.check` and `Guards.verify` (async use cases) wait;
  `Acl.can`/`canOpen`/`Guards.check` stay sync and throw on an async guard.
- **Routes** (ADR-0057): go_router from views only; `AppRoute`, `goTo/pushTo/goBack`, typed path and query
  parameters, deep links, `shell` tabs, `notFound`, `ScreenTransition` per screen; routes nested by path
  prefix (back returns to the parent).
- **Network**: `NetworkManager` (connection and quality; probes only when connectivity changes; on web trusts
  the browser), `NetworkManager.fixed`, `NetworkWrapper`, `NetworkBuilder`.
- **Http**: `Repository.send/attempt`, in-memory cache with TTL and cap (`MemoryCache(maxEntries = 256)`),
  retry with growing waits, interceptors `HttpLogInterceptor`, `SessionInterceptor`, `EventInterceptor`.
  `WebSocket` uses `dart:io` (does not work on web).
- **Logs** (ADR-0078, `spec/flutter.md` §6.17, `lib/src/log/log.dart`): `Log.d/i/s/w/e` (+ long names); one
  block per log with breadcrumb `component › kind › Class.method`, time, message, `data` as JSON, error, stack
  and the `.nuc:line` at the foot (written by the transpiler, `at`). Thick frame and level badge in Bootstrap
  dark alert colors, code colors in crumbs and data, Dragonfly purple; only the error's line blinks. Pastel
  color per component (`LogColor`, stable hash; `logColor` in the `config`, `Dragonfly.addConfig(c,
  component:)`). Release: only warn and error. Masks `token`, `password`, `authorization`, `secret`, `cookie`.
  `Log.level`, `Log.colors`, `Log.console`, `Log.sink` (`LogEntry`). Flutter exceptions:
  `Log.catchFlutterErrors(app:)` (called by `startDragonfly`): double red frame, stack in columns, repeated
  errors shown once. The package logs http (request/response/error), splash `onLoad` failures and
  translations by itself. Not caught: async errors outside Flutter (no `PlatformDispatcher.onError`).
- **Forms** (ADR-0058): format validation in presentation, business validation in the domain (`@validate`).
  `Rules`, `FormManager` with `checkOf`/debounce, `DragonflyForm`, `FormTextField`, `FormCheckbox`,
  `FormInput<T>`, `FormSubmit`, `Validators`; bound by name.
- **Dialogs** (ADR-0059): `DragonflyDialog` header/body/footer (`.info/.success/.warning/.danger`, `size`,
  `autoClose`, `onClose`, `onCloseButton`, `onAccept`); `Popups.toast/snackbar/alert/confirm`, `PopupTheme`.
- **Translations** (ADR-0060): `assets/i18n/<locale>/<component>.json` + `shared.json`; `"key".tr({...})`;
  `Translations(locales, fallback, remote)`; `RemoteDictionaries` by version (files, or localStorage on web).
  No third-party libraries.
- **Splash** (ADR-0061, 0063): `SplashScreen(next, child, minDuration = 3 s, onLoad, onError)`; after it
  `goTo(next)`; `onError` with retry. `onLoad` has no timeout. Native splash: `@splash` (dialect).
- **Device text layer**: in debug the package exposes `__dragonflyTextLayer` (`lib/src/device/probe_web.dart`)
  for the terminal device.
- **Tests**: `package:dragonfly/testing.dart`: `DragonflyTest.start/respondWith/requests/replace/startSession`,
  `pumpScreen/pumpRouter/closeScreen`, `isOk/isErr`, `thenReturnAsync`.
