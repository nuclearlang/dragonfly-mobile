{{decorators}}class {{name}} extends Tools {
{{#params_list}}
{{#@first}}
  {{class_name}}({{params}});

{{/@first}}
  final {{type}} {{name}};
{{#@last}}

{{/@last}}
{{/params_list}}
  {{members}}

  /// The tools the model can call: the methods with a doc comment.
  @override
  List<Tool> tools() => [
{{#methods}}
{{#doc_text}}
        Tool<Map<String, dynamic>, Object?>(
          name: '{{name}}',
          description: {{doc_literal}},
          inputSchema: Schemas.object({ {{#params_list}}'{{name}}': {{#tinfo.list}}{'type': 'array', 'items': {{/tinfo.list}}{'type': '{{#tinfo.is.string}}string{{/tinfo.is.string}}{{#tinfo.is.int}}integer{{/tinfo.is.int}}{{#tinfo.is.double}}number{{/tinfo.is.double}}{{#tinfo.is.number}}number{{/tinfo.is.number}}{{#tinfo.is.boolean}}boolean{{/tinfo.is.boolean}}{{#tinfo.model}}object{{/tinfo.model}}'}{{#tinfo.list}}}{{/tinfo.list}}{{^@last}}, {{/@last}}{{/params_list}} }, [{{#params_list}}{{^optional}}{{^default}}'{{name}}', {{/default}}{{/optional}}{{/params_list}}]),
          fn: (input, _) async => ToolResult.response({{#async}}await {{/async}}{{name}}({{#params_list}}{{#tinfo.model}}{{tinfo.item}}.fromJson(Map<String, dynamic>.from(input['{{name}}'] as Map)){{/tinfo.model}}{{^tinfo.model}}input['{{name}}'] as {{type}}{{#optional}}?{{/optional}}{{^optional}}{{#default}}? ?? {{default}}{{/default}}{{/optional}}{{/tinfo.model}}{{^@last}}, {{/@last}}{{/params_list}})),
        ),
{{/doc_text}}
{{/methods}}
      ];
}
