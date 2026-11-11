{{#decor.screen.providers}}
{{decorators}}class {{name}} extends StatelessWidget {
  const {{name}}({super.key{{#params_list}}, {{#required}}required {{/required}}this.{{name}}{{#default}} = {{default}}{{/default}}{{/params_list}}});
{{#params_list}}
{{#@first}}

{{/@first}}
  final {{#type}}{{type}}{{/type}}{{^type}}dynamic{{/type}}{{#optional}}?{{/optional}} {{name}};
{{/params_list}}

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
        providers: [
{{#decor.screen.providers.items}}
          BlocProvider<{{.}}>(create: (_) => inject<{{.}}>()),
{{/decor.screen.providers.items}}
        ],
        child: _{{name}}View({{#params_list}}{{name}}: {{name}}{{^@last}}, {{/@last}}{{/params_list}}),
      );
}

class _{{name}}View extends StatefulWidget {
  const _{{name}}View({{#params_list}}{{#@first}}{{{/@first}}{{#required}}required {{/required}}this.{{name}}{{#default}} = {{default}}{{/default}}{{^@last}}, {{/@last}}{{#@last}}}{{/@last}}{{/params_list}});
{{#params_list}}
{{#@first}}

{{/@first}}
  final {{#type}}{{type}}{{/type}}{{^type}}dynamic{{/type}}{{#optional}}?{{/optional}} {{name}};
{{/params_list}}

  @override
  State<_{{name}}View> createState() => _{{name}}State();
}

class _{{name}}State extends State<_{{name}}View>{{clauses}} {
  {{members}}
}
{{/decor.screen.providers}}
{{^decor.screen.providers}}
{{decorators}}class {{name}} extends StatefulWidget {
  const {{name}}({super.key{{#params_list}}, {{#required}}required {{/required}}this.{{name}}{{#default}} = {{default}}{{/default}}{{/params_list}}});
{{#params_list}}
{{#@first}}

{{/@first}}
  final {{#type}}{{type}}{{/type}}{{^type}}dynamic{{/type}}{{#optional}}?{{/optional}} {{name}};
{{/params_list}}

  @override
  State<{{name}}> createState() => _{{name}}State();
}

class _{{name}}State extends State<{{name}}>{{clauses}} {
  {{members}}
}
{{/decor.screen.providers}}
