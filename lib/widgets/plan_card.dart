import 'package:flutter/material.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.name,
    required this.equipment,
    required this.onOpen,
    required this.onEdit,
  });

  final String name;
  final String equipment;
  final VoidCallback? onOpen;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: onEdit == null ? null : (_) => onEdit!(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Equipment: $equipment'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton(onPressed: onOpen, child: const Text('Open')),
                  OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
