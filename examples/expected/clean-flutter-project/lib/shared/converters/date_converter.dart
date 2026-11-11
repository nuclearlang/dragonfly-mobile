import 'package:json_annotation/json_annotation.dart';

/// The API sends dates as ISO 8601 text ("2017-11-10T12:56:33.798Z").
class DateConverter implements JsonConverter<DateTime, String> {
  const DateConverter();

  @override
  DateTime fromJson(String json) {
    return DateTime.tryParse(json)!;
  }

  @override
  String toJson(DateTime value) {
    return value.toIso8601String();
  }
}
