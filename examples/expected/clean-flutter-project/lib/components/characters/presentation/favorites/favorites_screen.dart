import 'package:clean_flutter_project/components/session/session_component.dart';
import 'package:dragonfly/dragonfly.dart';
import 'package:flutter/material.dart' hide Page;

/// Tab 1 of MainShell. Without a session the router goes to LoginScreen; with a session, the role "fan"
/// (or one that inherits it, like "admin") and PremiumGuard's approval are required; otherwise, DeniedScreen.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('characters.favorites.title'.tr()),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => confirmLogout(context),
          ),
        ],
      ),
      body: Center(child: Text('characters.favorites.body'.tr())),
    );
  }

  /// a warning dialog with the Close / Accept footer (onAccept)
  void confirmLogout(BuildContext context) {
    DragonflyDialog.warning(
      header: Text('session.logout.title'.tr()),
      onAccept: () => inject<SessionComponent>().logout(),
      child: Text('session.logout.message'.tr()),
    ).show(context);
  }
}
