{{#decor.test}}
test({{decor.test.arg}}, () async {
  {{body}}
});
{{/decor.test}}
{{#decor.widget}}
testWidgets({{decor.widget.arg}}, ({{#params_list}}{{name}}{{/params_list}}) async {
  {{body}}
});
{{/decor.widget}}
{{#decor.states}}
blocTest(
  {{decor.states.arg}},
  build: () => {{#params_list}}inject<{{type}}>(){{/params_list}},
{{#decor.states.seed}}
  seed: () => {{decor.states.seed}},
{{/decor.states.seed}}
  act: ({{#params_list}}{{name}}{{/params_list}}) async {
    {{body}}
  },
{{#decor.states.wait}}
  wait: {{decor.states.wait}},
{{/decor.states.wait}}
{{#decor.states.skip}}
  skip: {{decor.states.skip}},
{{/decor.states.skip}}
  expect: () => {{decor.states.expect}},
);
{{/decor.states}}
{{^decor.test}}
{{^decor.widget}}
{{^decor.states}}
{{name}}(() async {
  {{body}}
});
{{/decor.states}}
{{/decor.widget}}
{{/decor.test}}
