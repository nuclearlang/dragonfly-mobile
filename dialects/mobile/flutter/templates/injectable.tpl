{{decorators}}class {{name}} {
{{#params_list}}
{{#@first}}
  {{class_name}}({{params}});

{{/@first}}
  final {{type}} {{name}};
{{#@last}}

{{/@last}}
{{/params_list}}
  {{members}}
}
