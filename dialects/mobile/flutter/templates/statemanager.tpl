{{decorators}}class {{name}} extends StateManager<{{decor.stateModel.arg}}> {
{{#ctor}}
  {{ctor}}
{{/ctor}}
{{^ctor}}
  {{class_name}}() : super(const {{decor.stateModel.arg}}.initial());
{{/ctor}}
{{#params_list}}
{{#@first}}

{{/@first}}
  final {{type}} {{name}};
{{/params_list}}

  {{members}}
}
