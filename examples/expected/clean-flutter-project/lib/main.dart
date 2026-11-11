import 'package:clean_flutter_project/dragonfly.g.dart';
import 'package:clean_flutter_project/shared/widgets/offline_banner.dart';
import 'package:dragonfly/dragonfly.dart';
import 'package:flutter/material.dart' hide Page;

Future<void> main() async {
  await startDragonfly();
  runApp(App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'shared.app.title'.tr(),
      locale: Translations.locale,
      supportedLocales: Translations.supportedLocales,
      localizationsDelegates: Translations.delegates,
      routerConfig: appRouter,
      builder: (context, child) => NetworkWrapper(offline: OfflineBanner(), child: child!),
    );
  }
}
