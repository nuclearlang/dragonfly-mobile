---
layer: L3
component: dragonfly-mobile
read-when: you work on the layout of a Dragonfly project, config.nuc, assets, architecture rules or project package definitions
---

# Dragonfly project (`spec/flutter.md` §3)

- **Only `.nuc` files and `assets/`** (ADR-0050). No `nuclear.toml`; the project name is the folder. Everything
  generated goes to `build/` (the app in `build/app`) and is never edited.
- Layout: `main.nuc`, `config.nuc`, `config/` (appConfig), `shared/` (`widgets events models converters
  components guards screens`), `components/<c>/` (facade `<c>_component.nuc`, `config/`, `data/`,
  `domain/{models, usecases, aggregates, services}`, `presentation/<screen>/{managers, state_models, forms}`,
  `presentation/widgets`), `assets/i18n/<locale>/`, `assets/splash/`, `test/`, `integration_test/`.
- Kind by folder: a declaration without a header word in `models/`, `state_models/`, `forms/`, `test/` or
  `integration_test/` takes its folder's kind. What is in `test/` is only visible to files in `test/`.

## config.nuc (ADR-0065, 0066, 0069, 0070; `spec/flutter.md` §3.1)

The project's pubspec in Nuclear: `app(name, description, version, usesMaterialDesign)`, `environment(sdk,
flutter)`, `dependencies(package = "version")`, `devDependencies(...)`. An empty section is not written. Not
transpiled; errors are N0303. Only third-party packages the framework does not use: Dragonfly's own
(dragonfly, flutter_bloc, fpdart, go_router, json_annotation, build_runner, json_serializable, mocktail,
bloc_test, integration_test, flutter_native_splash) are added automatically and visible in
`build/app/pubspec.yaml`; listing one is N0303 on its line and `dragonfly flutter add` rejects it. A project
without `config.nuc` gets one on its first `check`/`build`.

## Assets by convention (ADR-0071, `spec/flutter.md` §3.2)

No assets section: `assets/fonts/<Family>/<Family>-BoldItalic.ttf` → `fonts:` (weight and style from the name;
`Oblique` = italic; two equal files are an error), `assets/shaders/*.frag` → `shaders:`, any other folder →
`assets:`; rewritten on every build. No `dependency_overrides`: the project only adds.

## Definitions of project packages

Each dependency gets type definitions generated once into `~/.cache/nuclearlang/defs` and listed in
`build/defs.lock` (imports, overrides, hover). Debugging a name of a package without an import: look at
`build/defs.lock` and the cache (`nuclear defs show` does not see them). The editor uses the same lock.

## Architecture rules (the linter, ADR-0046; `spec/projects.md` §4)

The transpiler checks the dialect's `[architecture]` across the whole project; all are errors; the editor
shows them. Who calls whom (N0301): usecase ← appcomponent; service ← usecase or aggregate; aggregate ← usecase;
repository ← usecase or aggregate; `BuildContext`/`GoRouter`/`appRouter` only in views
(`[architecture.names]`). Closed components (N0302): visible from another component are the appcomponent,
models, converters, events, global components, guards and screens. Tests may use everything. One injector
(GetIt); privacy is checked by the transpiler, not the runtime. Open questions (warnings, disabling per file,
new rules) are in `STATUS.md`.
