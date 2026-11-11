import 'package:json_annotation/json_annotation.dart';

part 'character_error.g.dart';

/// Business error of the component: dragonfly builds it with the failure message.
@JsonSerializable(explicitToJson: true)
class CharacterError {
  const CharacterError({required this.message});

  factory CharacterError.fromJson(Map<String, dynamic> json) => _$CharacterErrorFromJson(json);

  final String message;

  Map<String, dynamic> toJson() => _$CharacterErrorToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterError &&
          message == other.message;

  @override
  int get hashCode => Object.hashAll([message]);
}
