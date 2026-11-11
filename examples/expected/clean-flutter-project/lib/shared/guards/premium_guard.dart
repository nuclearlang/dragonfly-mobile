import 'package:dragonfly/dragonfly.dart';

/// Guard: a custom access check, like NestJS CanActivate.
class PremiumGuard extends Guard {
  PremiumGuard(this.session);

  final SessionManager session;

  @override
  bool canActivate() {
    return session.value<bool>('premium') != false;
  }
}
