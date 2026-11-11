{{#decor.state}}
{{#async}}Future<void>{{/async}}{{^async}}void{{/async}} {{name}}({{params}}){{#async}} async{{/async}} {
{{#decor.before}}
  {{decor.before.arg}}();
{{/decor.before}}
{{#ret_info.result}}
  final result = {{#async}}await {{/async}}_{{name}}({{call_args}});
  emit(result.match({{owner_decor.stateModel.arg}}.error, {{decor.state.arg}}));
{{/ret_info.result}}
{{^ret_info.result}}
  emit({{decor.state.arg}}({{#async}}await {{/async}}_{{name}}({{call_args}})));
{{/ret_info.result}}
{{#decor.after}}
  {{decor.after.arg}}();
{{/decor.after}}
}

{{ret}} _{{name}}({{params}}){{#async}} async{{/async}} {
  {{body}}
}
{{/decor.state}}
{{^decor.state}}
{{#override}}
@override
{{/override}}
{{#ret}}{{ret}} {{/ret}}{{name}}({{params}}){{#async}} async{{/async}} {
{{#decor.before}}
  {{decor.before.arg}}();
{{/decor.before}}
{{#decor.after}}
  try {
    {{body}}
  } finally {
    {{decor.after.arg}}();
  }
{{/decor.after}}
{{^decor.after}}
  {{body}}
{{/decor.after}}
}
{{/decor.state}}
