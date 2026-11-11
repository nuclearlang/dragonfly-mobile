@JsonSerializable(explicitToJson: true{{#generic_list}}{{#@first}}, genericArgumentFactories: true{{/@first}}{{/generic_list}})
{{decorators}}class {{name}}{{generics}}{{#implements}} implements {{implements}}{{/implements}} {
  const {{class_name}}({{#fields}}{{#@first}}{{{/@first}}{{^optional}}{{^default}}required {{/default}}{{/optional}}this.{{name}}{{#default}} = {{default}}{{/default}}{{^@last}}, {{/@last}}{{#@last}}}{{/@last}}{{/fields}});

{{^generic_list}}
  factory {{class_name}}.fromJson(Map<String, dynamic> json) => _${{class_name}}FromJson(json);
{{/generic_list}}
{{#generic_list}}
{{#@first}}
  factory {{class_name}}.fromJson(Map<String, dynamic> json{{/@first}}, {{name}} Function(Object? json) fromJson{{name}}{{#@last}}) =>
      _${{class_name}}FromJson(json{{/@last}}{{/generic_list}}{{#generic_list}}, fromJson{{name}}{{#@last}});
{{/@last}}
{{/generic_list}}

{{#fields}}
{{#decor.key}}
  @JsonKey(name: {{decor.key.arg}})
{{/decor.key}}
  {{#decorators}}{{decorators}}{{/decorators}}final {{type}}{{#optional}}?{{/optional}} {{name}};
{{/fields}}

{{^generic_list}}
  Map<String, dynamic> toJson() => _${{class_name}}ToJson(this);
{{/generic_list}}
{{#generic_list}}
{{#@first}}
  Map<String, dynamic> toJson({{/@first}}Object? Function({{name}} value) toJson{{name}}{{^@last}}, {{/@last}}{{#@last}}) =>
      _${{class_name}}ToJson(this{{/@last}}{{/generic_list}}{{#generic_list}}, toJson{{name}}{{#@last}});
{{/@last}}
{{/generic_list}}

{{^generic_list}}
{{#field_decor.primary}}

  /// The local table of {{class_name}} (`@primary`): its rows by `{{field_decor.primary}}`, CRUD and queries on the device.
  static final LocalTable<{{class_name}}> table = LocalTable<{{class_name}}>(
    {{#decor.entity.arg}}{{decor.entity.arg}}{{/decor.entity.arg}}{{^decor.entity.arg}}'{{name|snake}}'{{/decor.entity.arg}},
    {{class_name}}.fromJson,
    key: {{#fields}}{{#decor.primary}}{{#decor.key}}{{decor.key.arg}}{{/decor.key}}{{^decor.key}}'{{name}}'{{/decor.key}}{{/decor.primary}}{{/fields}},
{{#fields}}
{{#decor.primary.generated}}
    generated: true,
{{/decor.primary.generated}}
{{/fields}}
{{#fields}}
{{#decor.created}}
    created: {{#decor.key}}{{decor.key.arg}}{{/decor.key}}{{^decor.key}}'{{name}}'{{/decor.key}},
{{/decor.created}}
{{#decor.updated}}
    updated: {{#decor.key}}{{decor.key.arg}}{{/decor.key}}{{^decor.key}}'{{name}}'{{/decor.key}},
{{/decor.updated}}
{{/fields}}
  );
{{/field_decor.primary}}
{{/generic_list}}

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is {{class_name}}{{#fields}} &&
          {{#tinfo.list}}listEquals({{name}}, other.{{name}}){{/tinfo.list}}{{^tinfo.list}}{{name}} == other.{{name}}{{/tinfo.list}}{{/fields}};

  @override
  int get hashCode => Object.hashAll([{{#fields}}{{#tinfo.list}}Object.hashAll({{name}}{{#optional}} ?? const []{{/optional}}){{/tinfo.list}}{{^tinfo.list}}{{name}}{{/tinfo.list}}{{^@last}}, {{/@last}}{{/fields}}]);
{{#methods_code}}

  {{methods_code}}
{{/methods_code}}
}
