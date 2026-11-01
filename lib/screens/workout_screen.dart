import 'package:flutter/material.dart';

import 'plan_editor_screen.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({
    super.key,
    required this.planName,
    required this.equipment,
  });

  final String planName;
  final String equipment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Current workout')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(planName, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Equipment: $equipment'),
            const SizedBox(height: 16),
            const Text('Example plan — not saved'),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          PlanEditorScreen(planName: planName),
                    ),
                  );
                },
                child: const Text('Edit plan'),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Workout tracking is not available yet.'),
          ],
        ),
      ),
    );
  }
}
