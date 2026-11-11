{{decorators}}class {{name}} {
  const {{class_name}}({{#fields}}{{#@first}}{{{/@first}}{{^optional}}required {{/optional}}this.{{name}}{{^@last}}, {{/@last}}{{#@last}}}{{/@last}}{{/fields}});

{{#fields}}
  final {{type}}{{#optional}}?{{/optional}} {{name}};
{{/fields}}

  /// The rules of each field, in the order they are checked.
  static final Map<String, List<Rule>> rules = {
{{#fields}}
    '{{name}}': [
{{#decor.required}}
      Rules.required({{decor.required.args}}),
{{/decor.required}}
{{#tinfo.is.int}}
      Rules.number(),
{{/tinfo.is.int}}
{{#tinfo.is.double}}
      Rules.number(),
{{/tinfo.is.double}}
{{#decor.email}}
      Rules.email({{decor.email.args}}),
{{/decor.email}}
{{#decor.url}}
      Rules.url({{decor.url.args}}),
{{/decor.url}}
{{#decor.minLength}}
      Rules.minLength({{decor.minLength.args}}),
{{/decor.minLength}}
{{#decor.maxLength}}
      Rules.maxLength({{decor.maxLength.args}}),
{{/decor.maxLength}}
{{#decor.min}}
      Rules.min({{decor.min.args}}),
{{/decor.min}}
{{#decor.max}}
      Rules.max({{decor.max.args}}),
{{/decor.max}}
{{#decor.pattern}}
      Rules.pattern({{decor.pattern.args}}),
{{/decor.pattern}}
{{#decor.matches}}
      Rules.matches({{decor.matches.args}}),
{{/decor.matches}}
    ],
{{/fields}}
  };

  /// The values of a new form.
  static const Map<String, Object?> initial = {
{{#fields}}
    '{{name}}': {{#default}}{{default}}{{/default}}{{^default}}{{#tinfo.is.string}}''{{/tinfo.is.string}}
{{#tinfo.is.boolean}}false{{/tinfo.is.boolean}}{{^tinfo.is.string}}{{^tinfo.is.boolean}}null{{/tinfo.is.boolean}}{{/tinfo.is.string}}{{/default}},
{{/fields}}
  };

  static {{class_name}} fromValues(Map<String, Object?> v) => {{class_name}}(
{{#fields}}
        {{name}}: {{#tinfo.is.int}}Rules.asInt(v['{{name}}']){{^optional}}!{{/optional}}{{/tinfo.is.int}}
{{#tinfo.is.double}}Rules.asDouble(v['{{name}}']){{^optional}}!{{/optional}}{{/tinfo.is.double}}
{{#tinfo.is.boolean}}v['{{name}}'] == true{{/tinfo.is.boolean}}{{^tinfo.is.int}}{{^tinfo.is.double}}{{^tinfo.is.boolean}}v['{{name}}'] as {{type}}{{#optional}}?{{/optional}}{{/tinfo.is.boolean}}{{/tinfo.is.double}}{{/tinfo.is.int}},
{{/fields}}
      );
{{#methods_code}}

  {{methods_code}}
{{/methods_code}}
}
