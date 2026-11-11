@JsonSerializable(explicitToJson: true)
{{decorators}}class {{name}} extends AppEvent {
  const {{class_name}}({{#fields}}{{#@first}}{{{/@first}}{{^optional}}{{^default}}required {{/default}}{{/optional}}this.{{name}}{{#default}} = {{default}}{{/default}}{{^@last}}, {{/@last}}{{#@last}}}{{/@last}}{{/fields}});

  factory {{class_name}}.fromJson(Map<String, dynamic> json) => _${{class_name}}FromJson(json);
{{#fields}}
{{#@first}}

{{/@first}}
{{#decor.key}}
  @JsonKey(name: {{decor.key.arg}})
{{/decor.key}}
  {{#decorators}}{{decorators}}{{/decorators}}final {{type}}{{#optional}}?{{/optional}} {{name}};
{{/fields}}

  @override
  String get eventName => '{{name}}';

  @override
  Map<String, dynamic> toJson() => _${{class_name}}ToJson(this);
}
