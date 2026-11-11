enum {{class_name}}Status { initial{{#params_list}}, {{name}}{{/params_list}} }

{{decorators}}class {{name}} {
  const {{class_name}}._({required this.status{{#params_list}}{{^tinfo.is.boolean}}, this.{{name}}{{/tinfo.is.boolean}}{{/params_list}}});

  const {{class_name}}.initial() : this._(status: {{class_name}}Status.initial);
{{#params_list}}
{{#tinfo.is.boolean}}
  const {{class_name}}.{{name}}() : this._(status: {{class_name}}Status.{{name}});
{{/tinfo.is.boolean}}
{{^tinfo.is.boolean}}
  const {{class_name}}.{{name}}({{type}} {{name}}) : this._(status: {{class_name}}Status.{{name}}, {{name}}: {{name}});
{{/tinfo.is.boolean}}
{{/params_list}}

  final {{class_name}}Status status;
{{#params_list}}
{{^tinfo.is.boolean}}
  final {{type}}? {{name}};
{{/tinfo.is.boolean}}
{{/params_list}}

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is {{class_name}} &&
          status == other.status{{#params_list}}{{^tinfo.is.boolean}} &&
          {{#tinfo.list}}listEquals({{name}}, other.{{name}}){{/tinfo.list}}{{^tinfo.list}}{{name}} == other.{{name}}{{/tinfo.list}}{{/tinfo.is.boolean}}{{/params_list}};

  @override
  int get hashCode => Object.hash(status, Object.hashAll([{{#params_list}}{{^tinfo.is.boolean}}{{#tinfo.list}}Object.hashAll({{name}} ?? const []){{/tinfo.list}}{{^tinfo.list}}{{name}}{{/tinfo.list}}, {{/tinfo.is.boolean}}{{/params_list}}]));

  @override
  String toString() => '{{class_name}}.${status.name}';
{{#methods_code}}

  {{methods_code}}
{{/methods_code}}
}

/// One widget for each state of [{{class_name}}]; a state without a builder shows [orElse].
class {{class_name}}Builder<M extends StateStreamable<{{class_name}}>> extends StatelessWidget {
  const {{class_name}}Builder({super.key, this.initial{{#params_list}}, this.{{name}}{{/params_list}}, this.orElse});

  final Widget Function()? initial;
{{#params_list}}
  final Widget Function({{^tinfo.is.boolean}}{{type}} {{name}}{{/tinfo.is.boolean}})? {{name}};
{{/params_list}}
  final Widget Function()? orElse;

  @override
  Widget build(BuildContext context) => BlocBuilder<M, {{class_name}}>(
        builder: (context, state) =>
            switch (state.status) {
              {{class_name}}Status.initial => initial?.call(),
{{#params_list}}
              {{class_name}}Status.{{name}} => {{name}}?.call({{^tinfo.is.boolean}}state.{{name}}!{{/tinfo.is.boolean}}),
{{/params_list}}
            } ??
            orElse?.call() ??
            const SizedBox.shrink(),
      );
}
