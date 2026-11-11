import 'package:clean_flutter_project/shared/converters/date_converter.dart';
import 'package:clean_flutter_project/shared/converters/uri_converter.dart';
import 'package:json_annotation/json_annotation.dart';

part 'episode.g.dart';

@JsonSerializable(explicitToJson: true)
class Episode {
  const Episode({required this.id, required this.name, required this.episode, required this.airDate, required this.created, required this.url});

  factory Episode.fromJson(Map<String, dynamic> json) => _$EpisodeFromJson(json);

  final int id;
  final String name;
  final String episode;
  @JsonKey(name: 'air_date')
  final String airDate;
  @DateConverter()
  final DateTime created;
  @UriConverter()
  final Uri url;

  Map<String, dynamic> toJson() => _$EpisodeToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Episode &&
          id == other.id &&
          name == other.name &&
          episode == other.episode &&
          airDate == other.airDate &&
          created == other.created &&
          url == other.url;

  @override
  int get hashCode => Object.hashAll([id, name, episode, airDate, created, url]);
}
