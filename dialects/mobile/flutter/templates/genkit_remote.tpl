{{decorators}}class {{name}} extends RemoteFlows {
{{#params_list}}
{{#@first}}
  {{class_name}}({{params}});

{{/@first}}
  final {{type}} {{name}};
{{#@last}}

{{/@last}}
{{/params_list}}
  @override
  String get baseUrl => {{decor.remote.arg}};

  {{members}}
}
