#!/usr/bin/env bash
# Transpiles every Flutter/Dart example with the transpiler and checks the result with `flutter analyze`.
# Needs the Flutter SDK (FLUTTER=path/to/flutter/bin/flutter, default: flutter in PATH).
# Uses tools/defs/flutter_project as the host project.
set -euo pipefail
# the working tree (plan 006): this repository (dragonfly-mobile) inside the `nuclear` one, or NUCLEAR_ROOT
HERE="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="${NUCLEAR_ROOT:-$(cd "$HERE/.." && pwd)}"
FLUTTER="${FLUTTER:-flutter}"
HOST="$ROOT/tools/defs/flutter_project"
OUT="$HOST/lib/generated"
rm -rf "$OUT" && mkdir -p "$OUT"
cargo build -q --release --manifest-path "$ROOT/Cargo.toml"
for src in "$HERE"/examples/examples-flutter-dialect/*.nuc "$@"; do
  name="$(basename "$src" .nuc)"
  dialect=flutter
  grep -qE '^(extension|mixin|data) ' "$src" && ! grep -qE '^(stateless|stateful) ' "$src" && dialect=dart
  "$ROOT/target/release/nuclear" build "$src" --dialect "$dialect" -o "$OUT/$name.dart"
done
(cd "$HOST" && "$FLUTTER" pub get --offline >/dev/null && "$FLUTTER" analyze lib/generated)
