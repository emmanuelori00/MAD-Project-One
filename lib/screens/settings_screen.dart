import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text('Settings are not available yet.'),
        SizedBox(height: 8),
        Text(
          'Equipment preference, default effort, and reduced animation will be set here.',
        ),
      ],
    );
  }
}
