import 'package:dragonfly/dragonfly.dart';

/// Form model: the login fields and their rules. Each form field (FormTextField("user"))
/// is bound by its name; the messages are dictionary keys or the text itself.
class LoginForm {
  const LoginForm({required this.user, required this.pass});

  final String user;
  final String pass;

  /// The rules of each field, in the order they are checked.
  static final Map<String, List<Rule>> rules = {
    'user': [
      Rules.required(),
      Rules.minLength(3),
    ],
    'pass': [
      Rules.required(),
      Rules.minLength(5, message: 'session.login.shortPass'),
    ],
  };

  /// The values of a new form.
  static const Map<String, Object?> initial = {
    'user': ''
,
    'pass': ''
,
  };

  static LoginForm fromValues(Map<String, Object?> v) => LoginForm(
        user:

v['user'] as String,
        pass:

v['pass'] as String,
      );
}
