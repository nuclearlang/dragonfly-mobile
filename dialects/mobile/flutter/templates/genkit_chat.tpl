{{decorators}}class {{name}} extends Chat {
{{#params_list}}
{{#@first}}
  {{class_name}}({{params}});

{{/@first}}
  final {{type}} {{name}};
{{#@last}}

{{/@last}}
{{/params_list}}
  @override
  List<Object?> get dependencies => [{{#params_list}}{{name}}{{^@last}}, {{/@last}}{{/params_list}}];
{{#members}}

  {{members}}
{{/members}}
}
