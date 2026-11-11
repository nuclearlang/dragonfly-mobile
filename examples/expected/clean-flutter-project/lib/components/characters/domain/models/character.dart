import 'package:dragonfly/dragonfly.dart';
import 'package:flutter/foundation.dart' hide Page;
import 'package:json_annotation/json_annotation.dart';

part 'character.g.dart';

@JsonSerializable(explicitToJson: true)
class Origin {
  const Origin({required this.name, required this.url});

  factory Origin.fromJson(Map<String, dynamic> json) => _$OriginFromJson(json);

  final String name;
  final String url;

  Map<String, dynamic> toJson() => _$OriginToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Origin &&
          name == other.name &&
          url == other.url;

  @override
  int get hashCode => Object.hashAll([name, url]);
}

@JsonSerializable(explicitToJson: true)
class Location {
  const Location({required this.name, required this.url});

  factory Location.fromJson(Map<String, dynamic> json) => _$LocationFromJson(json);

  final String name;
  final String url;

  Map<String, dynamic> toJson() => _$LocationToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Location &&
          name == other.name &&
          url == other.url;

  @override
  int get hashCode => Object.hashAll([name, url]);
}

/// the local table is named characters (without @entity: character, the model's name in snake_case)
@JsonSerializable(explicitToJson: true)
class Character {
  const Character({required this.id, required this.name, required this.status, required this.species, required this.type, required this.gender, required this.origin, required this.location, required this.image, required this.episode, required this.url, required this.created});

  factory Character.fromJson(Map<String, dynamic> json) => _$CharacterFromJson(json);

  final int id;
  final String name;
  final String status;
  final String species;
  final String type;
  final String gender;
  final Origin origin;
  final Location location;
  final String image;
  final List<String> episode;
  final String url;
  final String created;

  Map<String, dynamic> toJson() => _$CharacterToJson(this);

  /// The local table of Character (`@primary`): its rows by `id`, CRUD and queries on the device.
  static final LocalTable<Character> table = LocalTable<Character>(
    'characters',
    Character.fromJson,
    key: 'id',
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Character &&
          id == other.id &&
          name == other.name &&
          status == other.status &&
          species == other.species &&
          type == other.type &&
          gender == other.gender &&
          origin == other.origin &&
          location == other.location &&
          image == other.image &&
          listEquals(episode, other.episode) &&
          url == other.url &&
          created == other.created;

  @override
  int get hashCode => Object.hashAll([id, name, status, species, type, gender, origin, location, image, Object.hashAll(episode), url, created]);
}
