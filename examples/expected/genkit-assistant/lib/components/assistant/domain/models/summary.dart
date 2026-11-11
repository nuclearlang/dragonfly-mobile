import 'package:flutter/foundation.dart' hide Summary;
import 'package:json_annotation/json_annotation.dart';

part 'summary.g.dart';

/// What the summarize flow answers: the model fills it (structured output).
@JsonSerializable(explicitToJson: true)
class Summary {
  const Summary({required this.title, required this.points});

  factory Summary.fromJson(Map<String, dynamic> json) => _$SummaryFromJson(json);

  final String title;
  final List<String> points;

  Map<String, dynamic> toJson() => _$SummaryToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Summary &&
          title == other.title &&
          listEquals(points, other.points);

  @override
  int get hashCode => Object.hashAll([title, Object.hashAll(points)]);
}
