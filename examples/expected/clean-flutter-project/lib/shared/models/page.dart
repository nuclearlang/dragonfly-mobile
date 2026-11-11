import 'package:flutter/foundation.dart' hide Page;
import 'package:json_annotation/json_annotation.dart';

part 'page.g.dart';

/// A page of an API list: always info + results; only the model of each result changes
/// (Page<Character>, Page<Episode>...). It lives in shared/: every component uses it.
@JsonSerializable(explicitToJson: true)
class PageInfo {
  const PageInfo({required this.count, required this.pages, this.next, this.prev});

  factory PageInfo.fromJson(Map<String, dynamic> json) => _$PageInfoFromJson(json);

  final int count;
  final int pages;
  final String? next;
  final String? prev;

  Map<String, dynamic> toJson() => _$PageInfoToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PageInfo &&
          count == other.count &&
          pages == other.pages &&
          next == other.next &&
          prev == other.prev;

  @override
  int get hashCode => Object.hashAll([count, pages, next, prev]);
}

@JsonSerializable(explicitToJson: true, genericArgumentFactories: true)
class Page<T> {
  const Page({required this.info, required this.results});

  factory Page.fromJson(Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
      _$PageFromJson(json, fromJsonT);

  final PageInfo info;
  final List<T> results;

  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$PageToJson(this, toJsonT);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Page &&
          info == other.info &&
          listEquals(results, other.results);

  @override
  int get hashCode => Object.hashAll([info, Object.hashAll(results)]);
}
