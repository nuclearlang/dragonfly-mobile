{{decorators}}class {{name}} extends FormManager<{{decor.form.arg}}> {
{{#ctor}}
  {{ctor}}
{{/ctor}}
{{^ctor}}
  {{class_name}}() : super({{decor.form.arg}}.rules, {{decor.form.arg}}.initial, {{decor.form.arg}}.fromValues);
{{/ctor}}
{{#params_list}}
{{#@first}}

{{/@first}}
  final {{type}} {{name}};
{{/params_list}}
{{#methods}}
{{#@first}}

  @override
  FieldCheck? checkOf(String field) => switch (field) {
{{/@first}}
{{#decor.validate}}
        {{decor.validate.arg}} => (v) => {{name}}(v as {{#params_list}}{{type}}{{/params_list}}),
{{/decor.validate}}
{{#@last}}
        _ => null,
      };
{{/@last}}
{{/methods}}

  {{members}}
}
