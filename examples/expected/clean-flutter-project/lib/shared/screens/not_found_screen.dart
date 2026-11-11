import 'package:flutter/material.dart' hide Page;

/// The page for an address no screen has.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Page not found')));
  }
}
