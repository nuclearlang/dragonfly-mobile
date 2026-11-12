# Dialect `flutter`: the mobile platform in Dart

What this dialect adds to the platform's sheet: the app is generated as Flutter in `build/app` (never edit it); the UI
classes are Flutter's and Material's (`nuclear defs show <Name> --dialect flutter`). `dragonfly build`, `dragonfly
run` (hot reload), `dragonfly analyze` (Dart's analyzer over the generated app), `dragonfly test`, `dragonfly device`.
Full rules: `nuclear help flutter`.
