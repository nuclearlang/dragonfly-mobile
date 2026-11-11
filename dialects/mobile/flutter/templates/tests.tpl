{{#decor.mock.items}}
class Mock{{.}} extends Mock implements {{.}} {}

{{/decor.mock.items}}
void main() {
  group('{{name}}', () {
    setUp(() async {
      await DragonflyTest.start(dragonflyConfig(), registerDragonfly{{#decor.offline}}, NetworkStatus.offline{{/decor.offline}});
{{#decor.mock.items}}
      DragonflyTest.replace<{{.}}>(Mock{{.}}());
{{/decor.mock.items}}
    });

    {{members}}
  });
}
