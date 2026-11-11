import 'package:clean_flutter_project/components/characters/domain/models/character.dart';
import 'package:flutter/foundation.dart' hide Page;
import 'package:json_annotation/json_annotation.dart';

part 'character_params.g.dart';

@JsonSerializable(explicitToJson: true)
class CharacterParams {
  const CharacterParams({required this.name, required this.species, required this.type, required this.gender, required this.origin, required this.location, required this.image, required this.episode, required this.url});

  factory CharacterParams.fromJson(Map<String, dynamic> json) => _$CharacterParamsFromJson(json);

  final String name;
  final String species;
  final String type;
  final String gender;
  final Origin origin;
  final Location location;
  final String image;
  final List<String> episode;
  final String url;

  Map<String, dynamic> toJson() => _$CharacterParamsToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterParams &&
          name == other.name &&
          species == other.species &&
          type == other.type &&
          gender == other.gender &&
          origin == other.origin &&
          location == other.location &&
          image == other.image &&
          listEquals(episode, other.episode) &&
          url == other.url;

  @override
  int get hashCode => Object.hashAll([name, species, type, gender, origin, location, image, Object.hashAll(episode), url]);
}
