import 'package:clean_flutter_project/components/session/domain/models/auth.dart';
import 'package:dragonfly/dragonfly.dart';
import 'package:fpdart/fpdart.dart';

/// session.destroy deletes the session from the device, clears the cache and publishes SessionEnded.
class LogoutUseCase {
  LogoutUseCase(this.session);

  final SessionManager session;

  Future<Either<AuthError, bool>> exec() async {
    await session.destroy();
    return Right(true);
  }
}
