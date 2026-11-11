import 'package:clean_flutter_project/components/session/domain/models/auth.dart';
import 'package:clean_flutter_project/components/session/domain/usecases/login_usecase.dart';
import 'package:clean_flutter_project/components/session/domain/usecases/logout_usecase.dart';
import 'package:dragonfly/dragonfly.dart';
import 'package:fpdart/fpdart.dart';

class SessionComponent {
  Future<Either<AuthError, Auth>> login(String user, String pass) async {
    return await inject<LoginUseCase>().exec(user, pass);
  }

  Future<Either<AuthError, bool>> logout() async {
    return await inject<LogoutUseCase>().exec();
  }
}
