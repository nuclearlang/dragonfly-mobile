{{decorators}}class {{name}} implements JsonConverter<{{#methods}}{{#is.fromJson}}{{ret_info.type}}, {{#params_list}}{{type}}{{/params_list}}{{/is.fromJson}}{{/methods}}> {
  const {{class_name}}();

  {{methods_code}}
}
