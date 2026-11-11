{{decorators}}class {{name}} extends GenkitFlow<{{#methods}}{{#is.run}}{{#params_list}}{{#@first}}{{type}}{{/@first}}{{/params_list}}, {{ret_info.type}}{{/is.run}}{{/methods}}> {
{{#params_list}}
{{#@first}}
  {{class_name}}({{params}});

{{/@first}}
  final {{type}} {{name}};
{{#@last}}

{{/@last}}
{{/params_list}}
  @override
  String get flowName => '{{name|camel}}';

  {{members}}
}
