import 'package:flutter/material.dart' hide Page;

/// Widget shared by every component.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.red,
      child: Padding(padding: EdgeInsets.all(12), child: Text('No internet')),
    );
  }
}
