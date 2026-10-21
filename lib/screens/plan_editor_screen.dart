import 'package:flutter/material.dart';

class PlanEditorScreen extends StatelessWidget {
  const PlanEditorScreen({super.key, this.planName});

  final String? planName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(planName == null ? 'Add plan' : 'Edit plan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (planName != null) ...[
              Text(planName!, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
            ],
            const Text('Plan editing is not available yet.'),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
