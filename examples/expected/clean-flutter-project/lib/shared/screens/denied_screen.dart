import 'package:flutter/material.dart' hide Page;

class DeniedScreen extends StatelessWidget {
  const DeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Access denied')),
      body: Center(child: Text('You cannot open this screen')),
    );
  }
}
