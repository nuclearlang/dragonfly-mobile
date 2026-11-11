# The `mobile` platform of Dragonfly

> Inherits every rule of [nuclear-base.md](https://github.com/nuclearlang/nuclear/blob/main/spec/nuclear-base.md) and the standard library ([library.md](https://github.com/nuclearlang/nuclear/blob/main/spec/library.md)).
> This document defines the mobile platform (ADR-0093): apps for Android, iOS, desktop and web through one UI
> toolkit, written in Nuclear only. Today its only dialect is `flutter` ([flutter.md](flutter.md)), whose spec
> holds both the platform's rules and how Flutter writes them; this document is the platform's index. A project's
> Nuclear never changes between the dialects of the platform; only a use of a dialect's type definitions (a
> Flutter widget, a pub.dev package) ties code to that dialect.

## 1. Project

```
my_store/
├── config.nuc                         dragonfly(...), app(...), plugins(...), dependencies(...)
├── main.nuc                           main() + the App widget
├── config/project_config.nuc          appConfig: the connections of the app
├── components/<name>/                 appcomponent, config/, data/, domain/, presentation/, ai/
├── shared/                            widgets, events, guards, screens, components shared by the app
├── assets/                            by convention (images, fonts, translations)
└── test/*_test.nuc                    tests; integration_test/ on a device
```

`config.nuc` is the only manifest ([projects.md](https://github.com/nuclearlang/nuclear/blob/main/spec/projects.md) §1; [flutter.md](flutter.md) §3.1): the platform and
dialect, the app, the plugins and the third-party packages. The CLI (`dragonfly`, [flutter.md](flutter.md) §11)
creates, builds, runs and tests the project; `build/` is the dialect's app, never edited.

```nuclear
dragonfly(platform = "mobile", dialect = "flutter")
app(name = "my_store", description = "A Dragonfly app.", version = "1.0.0+1")
plugins(genkit = true, googleAI = true)
```

A backend written in Nuclear is consumed through its contract: `contracts(tasks_api = "../tasks_api")` in
`config.nuc` generates `contracts/tasks_api/` (models with their rules and key, one repository per controller) at
every build ([projects.md](https://github.com/nuclearlang/nuclear/blob/main/spec/projects.md) §1.2, ADR-0098; example `examples/examples-flutter-dialect/tasks_app`).

Rules of the platform: §3; architecture (who uses whom, what a component shows): §4; kinds by folder: [flutter.md](flutter.md) §3.

## 2. Kinds

| Area | Kinds and decorators | Rules |
|---|---|---|
| Widgets | `stateless`, `stateful`, `widget` (shared) | [flutter.md](flutter.md) §5 |
| Configuration | `appConfig`, `config`; connections `Http(baseUrl, ...)`, `WebSocket`, `Database`, `Storage`, the AI providers | §6.1 |
| Data | models (`@key`, converters, `@primary` → a local table), `repository` with `@get`/`@post`... (http calls, mapping, cache; `saveLocal` and `<method>AsLocal()`; local queries as a backend repository) | §6.2, §6.3 |
| Domain | `usecase`, `appcomponent`, `service`, `aggregate` | §6.4–6.6 |
| State | state models, `statemanager` (`@on`, `emit`) | §6.7, §6.8 |
| Screens | `@screen(route, ...)`, routes, transitions, `navigate` | §6.9 |
| Events | `event`, global events, `component` with `@on(Event)` | §6.10, §6.11 |
| Session and access | `Session`, ACL, `guard` with `canActivate` | §6.12, §6.13 |
| Forms and dialogs | `form`, `formmanager`, dialogs and popups | §6.14, §6.15 |
| Translations and logs | `translations`, `Log` | §6.16, §6.17 |
| Platform services | `@splash`, offline, network, devices | §6.18, §6.19 |
| AI (plugin `genkit`) | `tools`, `chat`, `flow`, `remote`, `knowledge`; providers `FirebaseAI`, `GoogleAI`, `VertexAI`, `OpenAI`, `Anthropic` | §6.20 |
| Tests | `tests` with `@test`, `@widget`, `@states`, `@mock`; `integration` | §8 |

### Plugins

`genkit` and its providers `firebaseAI`, `googleAI`, `vertexAI`, `openAI`, `anthropic` ([flutter.md](flutter.md)
§6.20, [projects.md](https://github.com/nuclearlang/nuclear/blob/main/spec/projects.md) §3.3).

## 3. Rules

1. **Golden rule:** performance, speed and readability of the syntax.
2. **Only the business logic in Nuclear.** Constructors, overrides, registration in the injector, JSON
   serialization, http calls, state handling and imports are written by the transpiler.
3. **Light clean architecture:** data, domain and presentation layers, plus what is shared. The layers exist in the
   generated code; in Nuclear you do not write interfaces nor classes that only pass data around.
4. **Closed components:** a business component is used from another only through its `appcomponent` (facade). The
   transpiler checks it (§4).
5. **The platform's runtime and the official ecosystem of the dialect:** what the UI toolkit lacks (http connections
   with cache and retries, session, events, network, ACL, the local database) comes from the dialect's runtime package; the rest from the
   libraries the dialect names ([flutter.md](flutter.md) §1).
6. **The local database is the backend's ORM on the device** (ADR-0096): a model with `@primary` (`@primary(generated = true)`,
   `@created`, `@updated` as in a backend entity; `@entity("table")` names the table) has a table, encrypted unless the
   project's or the component's config says otherwise (`local: LocalDatabase = LocalDatabase(encrypted = false)`),
   the same on every platform the toolkit builds for (phones, desktops, web); `@repository(saveLocal = true)` keeps what
   its GET methods answer and gives each one a `<method>AsLocal()` twin; the queries (`where`, `orderBy`, `limit`,
   `offset`, `getOne`, `getMany`, `paginate` → `Page<T>`, `count`, `exists`, `update`, `delete`) are the backend's. The Nuclear never names
   the storage engine.

## 4. Architecture

| Rule | Code |
|---|---|
| A `usecase` is only used from an `appcomponent` | `N0301` |
| A `service` is only used from a `usecase` or an `aggregate` | `N0301` |
| An `aggregate` is only used from a `usecase` | `N0301` |
| A `repository` is only used from a `usecase` or an `aggregate` | `N0301` |
| From another component (or from `shared/`, `config/` and `main.nuc`) only the `appcomponent`, the models (`model`), the converters (`converter`), the events (`event`), the global components (`component`), the guards (`guard`) and the screens (`@screen`) are visible | `N0302` |
| The UI toolkit's context and router belong to the views: only a `stateless` or a `stateful` uses them (the names: [flutter.md](flutter.md) §4) | `N0301` |
| Tests (`tests`, `integration`) may use any declaration | — |

## 5. What the dialect decides

Only how it is written: the language, the UI toolkit, the packages, the generated app and how to run it. The
rules of [flutter.md](flutter.md) §3 (project structure), §6 (the kinds) and §8 (tests) are the platform's too,
written next to their Flutter output; when a second mobile dialect exists, their Nuclear moves here and
`flutter.md` keeps the equivalences (ADR-0093 §6).
