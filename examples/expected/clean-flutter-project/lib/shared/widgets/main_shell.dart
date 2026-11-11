import 'package:dragonfly/dragonfly.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:go_router/go_router.dart';

/// Screens with shell = { widget: MainShell, tab: n } are its tabs; each one keeps its own stack.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigator});

  final StatefulNavigationShell navigator;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigator,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigator.currentIndex,
        onDestinationSelected: (index) => navigator.goBranch(index),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.people),
            label: 'shared.tabs.characters'.tr(),
          ),
          NavigationDestination(
            icon: Icon(Icons.star),
            label: 'shared.tabs.favorites'.tr(),
          ),
        ],
      ),
    );
  }
}
