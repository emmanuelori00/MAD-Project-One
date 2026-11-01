import 'package:flutter/material.dart';

import '../widgets/plan_card.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({
    super.key,
    required this.onAddPlan,
    required this.onOpenPlan,
    required this.onEditPlan,
  });

  final VoidCallback onAddPlan;
  final void Function(String name, String equipment) onOpenPlan;
  final void Function(String name) onEditPlan;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: onAddPlan,
            icon: const Icon(Icons.add),
            label: const Text('Add plan'),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Example plans — not saved'),
        const SizedBox(height: 12),
        PlanCard(
          name: 'Plan A',
          equipment: 'No equipment',
          onOpen: () => onOpenPlan('Plan A', 'No equipment'),
          onEdit: () => onEditPlan('Plan A'),
        ),
        PlanCard(
          name: 'Plan B',
          equipment: 'Dumbbells',
          onOpen: () => onOpenPlan('Plan B', 'Dumbbells'),
          onEdit: () => onEditPlan('Plan B'),
        ),
      ],
    );
  }
}
