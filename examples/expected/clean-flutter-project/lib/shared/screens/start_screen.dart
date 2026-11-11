import 'package:clean_flutter_project/components/characters/presentation/list/character_list_screen.dart';
import 'package:dragonfly/dragonfly.dart';
import 'package:flutter/material.dart' hide Page;

/// The splash: the logo for at least 2 s while the data loads; then, the list. @splash gives the
/// native screen (Android, iOS, web) the same background and logo, and makes /start the initial route.
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SplashScreen(
      next: CharacterListScreen(),
      minDuration: Duration(seconds: 2),
      onLoad: () async => await Future.delayed(Duration(seconds: 1)),
      onError: (context, error, retry) => Center(child: TextButton(onPressed: retry, child: Text('Retry'))),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Image.asset('assets/splash/logo.png', width: 128)),
      ),
    );
  }
}
