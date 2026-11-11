---
layer: L2
component: dragonfly-mobile
read-when: you touch the mobile platform (spec/mobile.md), dialects/mobile/flutter, packages/dragonfly, packages/dragonfly_genkit, the Flutter examples, or spec/flutter.md / spec/dragonfly.md
---

# Dragonfly for mobile — the platform and its dialect `flutter`

Future repository `dragonfly-mobile` (ADR-0093 amends ADR-0083). The platform (`spec/mobile.md`, Nuclear only) is what the
user writes; `flutter` is its only dialect today (`react-native`, `kotlin-multiplatform` planned). Three parts (ADR-0039,
0051):

- the **`flutter` dialect** (`dialects/mobile/flutter/`): kinds and decorators that transpile Nuclear to Dart and add
  behaviour (a `repository` with `@get` writes the http call, the mapping and the cache);
- the **Dart package `dragonfly`** (`packages/dragonfly/`): what Flutter lacks (http with cache and retries,
  the local database, events, session, ACL, network, routes, logs, forms, dialogs, translations, splash, test helpers).
  Independent and publishable (MIT, README/CHANGELOG, `example/`; `repository` missing in the pubspec);
- the CLI and editor extensions, documented in [cli](https://github.com/nuclearlang/dragonfly/blob/main/docs/context/cli/CONTEXT.md) and [editors](https://github.com/nuclearlang/nuclear/blob/main/docs/context/editors/CONTEXT.md).

Genkit (plugin `genkit`, ADR-0092): runtime `packages/dragonfly_genkit` (providers, tools, chat + ChatController,
GenkitFlow, RemoteFlows, Knowledge, Schemas, `testing.dart`), kinds `tools`/`chat`/`flow`/`remote`/`knowledge`, the
project file `lib/dragonfly_genkit.g.dart`; example `examples/examples-flutter-dialect/genkit-assistant`. Plugins of
`config.nuc`: `[project.plugins]` of the dialect ([projects.md](https://github.com/nuclearlang/nuclear/blob/main/spec/projects.md) §3.3).

Ecosystem libraries it relies on: `bloc`/`flutter_bloc`, `json_serializable`/`json_annotation`, `get_it`,
`dio`, `go_router`, `fpdart` (Result → `Either`), `flutter_secure_storage`, `hive_ce` (local database), `mocktail`, `bloc_test`.

## Code map

| Path | What it does |
|---|---|
| `dialects/mobile/flutter/dialect.toml` | kinds, decorators, `[architecture]`, `[project]`, `[project.manifest]`, `[call_site.Log]`, defs list |
| `dialects/mobile/flutter/templates/` | kind templates; `dragonfly_g.tpl` → `lib/dragonfly.g.dart` (startDragonfly, dragonflyConfig, registerDragonfly, buildRouter, appRouter); `generated_tests.tpl` → `test/dragonfly_generated_test.dart`; `model.tpl`, `converter.tpl`, `form.tpl`, `formmanager.tpl`, `native_splash.tpl` |
| `dialects/mobile/flutter/docs.toml` | editor docs of every kind and decorator (required by a test) |
| `packages/dragonfly/lib/` | runtime (see [runtime.md](runtime.md)); `testing.dart` for tests |
| `examples/examples-flutter-dialect/clean-flutter-project/` | the complete example (golden in `examples/expected/clean-flutter-project/`): `dragonfly test` 34 tests, integration on Linux, `flutter analyze` 0, `flutter build web` and `linux` |
| `spec/flutter.md` | the dialect: rules, structure, kinds with tables, startup, tests, CLI, editors (§11) |
| `spec/dragonfly.md` | the Dart package API |
| `docs/dragonfly/tutorial.md` | an app from scratch with `dragonfly` (`nuclear help tutorial`) |

## Rules of this area

- Language rules come from the base; this dialect adds kinds and decorators only as data in `dialects/mobile/flutter`.
- Generic mechanisms belong in Rust (projects, `decor`, `[decorators.args]`, `[architecture.names]`, call
  sites); Flutter specifics never do.
- The package must work on web: no `dart:isolate`/`dart:io` without `kIsWeb` guards.
- Project blocks of `spec/flutter.md` are regenerated with `tools/spec-check/dragonfly.py --fix` and checked
  by `dragonfly_spec_shows_the_real_output`.
- Roles the user asked for: Flutter architect, Flutter/native optimizer, transpiler architect, framework architect.

## L3 files

| File | read-when |
|---|---|
| [project.md](project.md) | project layout, `config.nuc`, assets, kind by folder, architecture rules, definitions of project packages |
| [kinds.md](kinds.md) | what a kind or decorator does and generates |
| [runtime.md](runtime.md) | a service of the Dart package (events, session, ACL, routes, http, logs, forms, dialogs, i18n, splash, tests) |
| [security.md](security.md) | security and performance rules to enforce or warn about |
