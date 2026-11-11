import 'dart:math' hide Point;

// Dialecto dart.
// `extension`, `mixin` and `data` are kinds, `with` is a clause, `abstract` a modifier:
// they all come from dialects/dart/dialect.toml, not from the base language.

extension NumberParsing on String {
  int parseInt() {
    return int.tryParse(this)!;
  }
}

class Animal {
  String name = '';
}

mixin Flyer on Animal {
  String fly() {
    return '$name is flying';
  }
}

class Bird extends Animal with Flyer {}

abstract class Shape {
  double area();
}

class Circle extends Shape {
  double radius;

  Circle(this.radius);

  @override
  double area() {
    return 3.14 * radius * radius;
  }
}

/// code generation: constructor, copyWith and toJson come from the kind's template
class Point {
  const Point({required this.x, required this.y});

  final double x;
  final double y;

  Point copyWith({double? x, double? y}) {
    return Point(x: x ?? this.x, y: y ?? this.y);
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  double distance() {
    return sqrt(x * x + y * y);
  }
}
