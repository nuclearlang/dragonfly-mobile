{{#decor.mock.items}}
class Mock{{.}} extends Mock implements {{.}} {}

{{/decor.mock.items}}
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('{{name}}', () {
{{#decor.mock.items}}
    setUp(() => DragonflyTest.replace<{{.}}>(Mock{{.}}()));
{{/decor.mock.items}}

    {{members}}
  });
}
