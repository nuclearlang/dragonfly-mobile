# AGENTS.md — dragonfly-mobile

The mobile platform of Dragonfly: apps for Android, iOS and the web written in Nuclear. Its dialect `flutter` (TOML + templates read by the `nuclear` compiler) and its Dart runtime, the `dragonfly` package (repositories over dio, state managers, events, sessions, ACL, routing, forms, a local database), plus `dragonfly_genkit` for AI.

This repository is a folder of the NuclearLang working tree (`nuclear/dragonfly-mobile`); the platform's rules are the
working tree's `../AGENTS.md` ([nuclear](https://github.com/nuclearlang/nuclear/blob/main/AGENTS.md)) and its state is `../STATUS.md`.

- Context of this repository: [docs/context/dragonfly-mobile/CONTEXT.md](docs/context/dragonfly-mobile/CONTEXT.md).
- What is inside: `dialects/mobile/` (the platform contract and the `flutter` dialect), `packages/{dragonfly,dragonfly_genkit}` (the Dart runtimes), `defs/dart/` (type definitions of Flutter and the packages), `spec/{mobile,flutter,dragonfly}.md`, `examples/`, `docs/`.
- Checks:

```sh
(cd .. && cargo test)                                  # builds the examples, compares the goldens
python3 tools/spec-check-dragonfly.py                  # the spec's 27 examples
(cd packages/dragonfly && flutter test && flutter analyze)
(cd examples/examples-flutter-dialect/tasks_app && dragonfly build && dragonfly test)
```
