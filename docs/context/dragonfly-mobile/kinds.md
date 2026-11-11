---
layer: L3
component: dragonfly-mobile
read-when: you need what a kind or decorator of the flutter dialect does or generates
---

# Kinds and decorators (`spec/flutter.md` §6)

| Kind | Rule |
|---|---|
| `appConfig` / `config` | global / per-component configuration: `Http(connectionName, baseUrl, timeouts, interceptors)`, `WebSocket(uri, connectionName, interceptors)`, global services; `logColor` |
| `model` | only the definition; the transpiler writes the immutable class, `fromJson`/`toJson` (json_serializable) and equality. Generics `Page<T>` (ADR-0062, `genericArgumentFactories`). `@key("json_name")`; `@Converter` on a field (ADR-0064). `@primary` (`@primary(generated = true)`: the table gives the key; + `@created`, `@updated`) give it a local table named by `@entity("table")` (`decor.entity.arg`, default snake_case): `static final LocalTable<M> table`, registered with its component in `registerDragonfly` (ADR-0096; `field_decor` in `model.tpl` and the project context) |
| `converter` | `fromJson(json: J) T` + `toJson(value: T) J` (+ optional `sample() T` for generated tests) → `JsonConverter<T, J>`; in `shared/converters/`, visible everywhere |
| `repository` | `@repository(path, connection, saveLocal)`; methods `@get/@post/@put/@patch/@delete(path, headers = {...}, cache, cacheKey, ttl, retry, local)`. A cached method generates `purge<Method>()`; `purgeCache(key)` always exists. Undecorated params: to the path if `:name`, else query (GET/DELETE) or body (POST/PUT/PATCH); `@path`, `@query`, `@body` force it. Automatic retries only on GET, PUT and DELETE. `saveLocal = true` / `@get(local = true)` (ADR-0096): a GET whose `ret_info.model` has `fields_decor.primary` (or `generated`) and no type args gets `local: 'Repo.method'` in `send` and a `<method>AsLocal()` twin (`recall`), both in `repository_method.tpl` under `{{#deco_args.local or owner_decor.repository.saveLocal}}`; the generated tests call the twin. A method with a body queries `local<M>()` (plain Dart method) |
| `usecase` | one method `exec`, always returns `Result`; guards `@requires(internet, session)` and `@acl(roles, permissions, guards)` |
| `appcomponent` | the facade: exposes the component's functions, usually aliases `getOne() = GetOneCharacterUseCase.exec` |
| `service`, `aggregate` | helpers of use cases |
| `statemodel` | each field is a state (a `bool` is a state without data); `initial` always exists; generates a typed `<Model>Builder<Manager>` |
| `statemanager` | a screen's Cubit: `@stateModel(M)`, `@state(M.field)` emits that state, `@before(f)`/`@after(f)`; a `@state` returning `Result` emits the error with the `Err` |
| `stateless` / `stateful` + `@screen` | `@screen(route, providers, loggedIn = { forward }, acl = { roles, permissions, guards, forward }, shell = { widget, tab }, notFound, transition = ScreenTransition.x)` (ADR-0055, 0085). `@splash(color!, image)` → native splash (ADR-0063) |
| `event` | typed global event (`shared/events/`) with `fromJson`/`toJson` and `eventName` (JSON fields only) |
| `component` | global component (`shared/components/`, ADR-0053): anyone uses it; its `@on(Event)` methods always receive |
| `guard` | `canActivate()` with injected dependencies, like NestJS; sync or async (`~`) |
| `form` / `formmanager` | form model with `@required @email @url @minLength @maxLength @min @max @pattern @matches` (with `message`); `@form(F)`, `@validate("field")` = remote validation with debounce (ADR-0058) |
| `tests` / `integration` | `@mock([X])` (mocktail), `@test`, `@states` (bloc_test), `@widget`, `@offline`; without decorator = setUp/tearDown; `X.m()` = `inject<X>().m()`; Result does not propagate (ADR-0049) |

- `Result<E, T>` is error first (Dart: fpdart `Either`, ADR-0047); `.ok()`/`.error()` by what the callback
  returns (ADR-0048).
- Navigation `context.goTo/pushTo/goBack(Screen(...))`, only in views.
- Generated: `lib/dragonfly.g.dart`, `test/dragonfly_generated_test.dart` (JSON of models, repository
  contracts, route guards, smoke), `flutter_native_splash.yaml` (only with `decorated.splash`). Generated tests
  ask the converter for a field's JSON: `const Conv().toJson(DateTime(2000))`, or `sample()` when it has one;
  an enum field gets `Enum.values.first.name`.
- Examples: `shared/models/page.nuc` (`Page<T>`, `PageInfo`), `episode.nuc` +
  `shared/converters/date_converter.nuc`, `shared/screens/start_screen.nuc` (the `@splash`, route `/start`,
  initial route).
- Every kind and decorator has its entry in `dialects/mobile/flutter/docs.toml` (ADR-0079).
