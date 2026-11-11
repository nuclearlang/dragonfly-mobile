import 'package:clean_flutter_project/shared/events/force_logout.dart';
import 'package:dragonfly/dragonfly.dart';

/// Global component: runs with every ForceLogout, wherever the user is. session.destroy publishes
/// SessionEnded, and the visible screen reacts (the others, when shown again).
class ForceLogoutComponent {
  ForceLogoutComponent(this.session);

  final SessionManager session;

  Future<void> exec(ForceLogout event) async {
    await session.destroy();
  }
}
