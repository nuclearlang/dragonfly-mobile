# Changelog

All notable changes to dragonfly-mobile are written here; versions follow [Semantic Versioning](https://semver.org).

## Unreleased

- First public version.
- `[[generators]]` in the platform: `dragonfly gen` writes a resource's models, repository, use cases, screen with its state manager and tests (ADR-0103).
- `[[generators.usecase]]`: `dragonfly gen usecase` adds a use case's alias to its component's facade and, with `--calls`, writes a use case over a repository method (ADR-0103).
- `[[generators.resource]]`: the repository is merged (`merge = true`), so an action added to a resource that exists gets the members it lacks (ADR-0105).
