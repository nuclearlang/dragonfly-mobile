import 'package:clean_flutter_project/components/session/data/auth_repository.dart';
import 'package:clean_flutter_project/components/session/domain/models/auth.dart';
import 'package:dragonfly/dragonfly.dart';
import 'package:fpdart/fpdart.dart';

/// Starts the session: the token goes in every request and the ACL checks the roles. session.start publishes
/// SessionStarted, and every screen with GlobalEvents or @screen(loggedIn) is notified.
class LoginUseCase {
  LoginUseCase(this.repository, this.session);

  final AuthRepository repository;
  final SessionManager session;

  Future<Either<AuthError, Auth>> exec(String user, String pass) async {
    final authResult = await repository.login(LoginParams(user: user, pass: pass));
    if (authResult case Left(:final value)) return Left(value);
    final auth = (authResult as Right<AuthError, Auth>).value;
    await session.start(auth, token: auth.token, roles: auth.roles);
    // the token is masked in the log: ***
    Log.i(
      'session started',
      data: {'user': user, 'token': auth.token},
      at: 'session › usecase › LoginUseCase.exec · components/session/domain/usecases/login_usecase.nuc:10',
    );
    return Right(auth);
  }
}
