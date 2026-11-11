# Dragonfly mobile

The mobile platform of Dragonfly: apps for Android, iOS and the web written in Nuclear. Its dialect `flutter` (TOML + templates read by the `nuclear` compiler) and its Dart runtime, the `dragonfly` package (repositories over dio, state managers, events, sessions, ACL, routing, forms, a local database), plus `dragonfly_genkit` for AI.

Start with the [Dragonfly tutorial](https://github.com/nuclearlang/dragonfly/blob/main/docs/dragonfly/tutorial.md) and [spec/mobile.md](spec/mobile.md).

## What is inside

`dialects/mobile/` (the platform contract and the `flutter` dialect), `packages/{dragonfly,dragonfly_genkit}` (the Dart runtimes), `defs/dart/` (type definitions of Flutter and the packages), `spec/{mobile,flutter,dragonfly}.md`, `examples/`, `docs/`.

## Working on it

It is built by the `nuclear` compiler and the `dragonfly` CLI, so it lives inside a clone of the
[nuclear](https://github.com/nuclearlang/nuclear) repository:

```sh
git clone https://github.com/nuclearlang/nuclear && cd nuclear
git clone https://github.com/nuclearlang/dragonfly-mobile
./install.sh
```

The checks before a change: [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[Apache-2.0](LICENSE).
