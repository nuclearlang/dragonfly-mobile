import 'package:clean_flutter_project/components/characters/data/character_repository.dart';
import 'package:clean_flutter_project/components/characters/domain/models/character.dart';
import 'package:clean_flutter_project/components/characters/domain/models/character_error.dart';
import 'package:clean_flutter_project/components/session/presentation/login/managers/login_form_manager.dart';
import 'package:clean_flutter_project/dragonfly.g.dart';
import 'package:clean_flutter_project/shared/models/page.dart';
import 'package:dragonfly/dragonfly.dart';
import 'package:dragonfly/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

/// The login form: the LoginForm rules and the remote validation of the user (the characters
/// repository is a mock). The messages come from assets/i18n/en.
class MockCharacterRepository extends Mock implements CharacterRepository {}

void main() {
  group('LoginFormTest', () {
    setUp(() async {
      await DragonflyTest.start(dragonflyConfig(), registerDragonfly);
      DragonflyTest.replace<CharacterRepository>(MockCharacterRepository());
    });

    setUp(() async {
      final Page<Character> found = Page(info: PageInfo(count: 1, pages: 1), results: []);
      when(() => inject<CharacterRepository>().search('rick')).thenReturnAsync(Right(found));
      when(() => inject<CharacterRepository>().search('nobody')).thenReturnAsync(Left(CharacterError(message: '404')));
    });

    test('the rules of LoginForm first, then the API for the user', () async {
      final form = inject<LoginFormManager>();
      form.change('user', 'nobody');
      form.change('pass', '123');
      expect(await form.submit((f) => null), isFalse);
      expect(form.state.errorOf('pass'), 'The password is too short');
      expect(form.state.errorOf('user'), 'Not a character of the show');
      form.change('user', 'rick');
      form.change('pass', 'c-137');
      expect(await form.submit((f) => null), isTrue);
    });
  });
}
