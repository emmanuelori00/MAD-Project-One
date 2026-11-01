import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text('No workout history yet.'),
        SizedBox(height: 8),
        Text('Saved sets will appear here when workout tracking is available.'),
      ],
    );
  }
}
