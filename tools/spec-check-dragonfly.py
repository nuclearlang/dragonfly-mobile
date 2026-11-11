#!/usr/bin/env python3
"""Keeps the Dragonfly examples of spec/flutter.md equal to the example project.

Each pair in the spec is a ```nuclear block, a caption `Output (`<lib|test|integration_test>/<path>.dart`...)` and a
```dart block; `Generated (`<lib|test>/<path>.dart`)` captions a Dart block alone. The Nuclear block must be the source
`<path>.nuc` of examples/examples-flutter-dialect/clean-flutter-project and the Dart block its golden
output (examples/expected/clean-flutter-project/lib/<path>.dart, without the imports).

    tools/spec-check-dragonfly.py          # report the blocks that differ
    tools/spec-check-dragonfly.py --fix    # rewrite them (after UPDATE_GOLDEN=1 cargo test)
"""
import os, re, sys

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.normpath(os.path.join(here, ".."))  # this repository (dragonfly-mobile)
spec_path = os.path.join(root, "spec", "flutter.md")
project = os.path.join(root, "examples", "examples-flutter-dialect", "clean-flutter-project")
fence = "`" * 3


def dart(path):
    lines = open(os.path.join(root, "examples", "expected", "clean-flutter-project", path)).read().split("\n")
    while lines and (lines[0].startswith("import ") or lines[0] == ""):
        lines.pop(0)
    return "\n".join(lines).strip()


def nuc(path):
    source = path[len("lib/"):] if path.startswith("lib/") else path
    return open(os.path.join(project, source[: -len(".dart")] + ".nuc")).read().strip()


text = open(spec_path).read()
pair = re.compile(
    fence + r"nuclear\n((?:(?!" + fence + r").)*?)\n" + fence + r"\n\n(Output \(`((?:lib|test|integration_test)/[^`]+)`[^\n]*\n\n)" + fence + r"dart\n((?:(?!" + fence + r").)*?)\n" + fence,
    re.S,
)
alone = re.compile(r"(Generated \(`((?:lib|test)/[^`]+)`\):\n\n)" + fence + r"dart\n((?:(?!" + fence + r").)*?)\n" + fence, re.S)
bad = 0


def fix_pair(m):
    global bad
    src, caption, path, out = m.group(1), m.group(2), m.group(3), m.group(4)
    want_src, want_out = nuc(path), dart(path)
    if src.strip() != want_src or out.strip() != want_out:
        bad += 1
        print("differs:", path)
    return f"{fence}nuclear\n{want_src}\n{fence}\n\n{caption}{fence}dart\n{want_out}\n{fence}"


def fix_alone(m):
    global bad
    caption, path, out = m.group(1), m.group(2), m.group(3)
    want = dart(path)
    if out.strip() != want:
        bad += 1
        print("differs:", path)
    return f"{caption}{fence}dart\n{want}\n{fence}"


new = alone.sub(fix_alone, pair.sub(fix_pair, text))
pairs = len(pair.findall(text)) + len(alone.findall(text))
if "--fix" in sys.argv[1:] and new != text:
    open(spec_path, "w").write(new)
    print(f"spec/flutter.md: rewrote {bad} blocks")
print(f"spec/flutter.md: {pairs} Dragonfly examples, {bad} differ")
sys.exit(1 if bad and "--fix" not in sys.argv[1:] else 0)
