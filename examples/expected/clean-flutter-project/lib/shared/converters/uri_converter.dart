import 'package:json_annotation/json_annotation.dart';

/// Addresses come as text; sample() is the value the generated tests use, since they cannot invent a Uri.
class UriConverter implements JsonConverter<Uri, String> {
  const UriConverter();

  @override
  Uri fromJson(String json) {
    return Uri.parse(json);
  }

  @override
  String toJson(Uri value) {
    return value.toString();
  }

  Uri sample() {
    return Uri.parse('https://rickandmortyapi.com/api/episode/1');
  }
}
