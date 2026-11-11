import 'package:clean_flutter_project/components/characters/characters_component.dart';
import 'package:clean_flutter_project/components/session/presentation/login/forms/login_form.dart';
import 'package:dragonfly/dragonfly.dart';

/// The state of the login form: only validations, no business logic (that is LoginManager).
/// @validate("user") is a remote validation: it runs when the field rules pass, 400 ms after
/// the last keystroke, and calls the component like any state manager.
class LoginFormManager extends FormManager<LoginForm> {
  LoginFormManager(this.characters) : super(LoginForm.rules, LoginForm.initial, LoginForm.fromValues);

  final CharactersComponent characters;

  @override
  FieldCheck? checkOf(String field) => switch (field) {
        'user' => (v) => knownUser(v as String),
        _ => null,
      };

  /// the user must be a character of the show
  Future<String?> knownUser(String value) async {
    final searchResult = await characters.search(value);
    if (searchResult.isRight()) {
      return null;
    } else {
      return 'session.login.unknownUser';
    }
  }
}
