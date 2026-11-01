import 'package:flutter/material.dart';

import '../data/app_settings.dart';
import '../data/gear_match.dart';
import '../data/training_log_store.dart';
import '../data/workout_plan.dart';
import '../widgets/plan_card.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({
    super.key,
    required this.plans,
    required this.entries,
    required this.preferredEquipment,
    required this.loaded,
    required this.busy,
    required this.finishedWorkouts,
    required this.settingsReady,
    required this.onRetry,
    required this.onAddPlan,
    required this.onOpenPlan,
    required this.onEditPlan,
    this.error,
    this.message,
  });

  final List<WorkoutPlan> plans;
  final List<TrainingEntry> entries;
  final String preferredEquipment;
  final bool loaded;
  final bool busy;
  final int finishedWorkouts;
  final bool settingsReady;
  final String? error;
  final String? message;
  final VoidCallback onRetry;
  final VoidCallback onAddPlan;
  final ValueChanged<WorkoutPlan> onOpenPlan;
  final ValueChanged<WorkoutPlan> onEditPlan;

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  String _equipment = '';
  bool _suggestionHidden = false;

  Object _inputs(PlansScreen screen) => (
    screen.preferredEquipment,
    Object.hashAll(
      screen.plans.map(
        (plan) => (
          plan.id,
          plan.title,
          plan.equipmentTag,
          plan.planNote,
          plan.effortPreference,
        ),
      ),
    ),
    Object.hashAll(
      screen.entries.map(
        (entry) => (
          entry.id,
          entry.workoutId,
          entry.sessionKey,
          entry.exerciseLabel,
          entry.reps,
          entry.loggedAt,
          entry.sessionFinished,
        ),
      ),
    ),
  );

  @override
  void didUpdateWidget(covariant PlansScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_inputs(oldWidget) != _inputs(widget)) _suggestionHidden = false;
  }

  @override
  Widget build(BuildContext context) {
    final ready = widget.loaded && !widget.busy && widget.error == null;
    final match = ready && widget.settingsReady
        ? matchGear(
            plans: widget.plans,
            entries: widget.entries,
            equipment: widget.preferredEquipment,
          )
        : null;
    final suggestion = match?.suggestion;
    final visible = widget.plans.where(
      (plan) => _equipment.isEmpty || plan.equipmentTag == _equipment,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: ready && widget.settingsReady ? widget.onAddPlan : null,
            icon: const Icon(Icons.add),
            label: const Text('Add plan'),
          ),
        ),
        if (!widget.settingsReady)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Load your defaults in Settings before adding a plan.'),
          ),
        const SizedBox(height: 16),
        if (widget.loaded)
          Text(
            'Finished workouts: ${widget.finishedWorkouts}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey(_equipment),
          initialValue: _equipment,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Filter by equipment'),
          items: [
            const DropdownMenuItem(value: '', child: Text('All equipment')),
            ...equipmentChoices
                .skip(1)
                .map(
                  (equipment) => DropdownMenuItem(
                    value: equipment,
                    child: Text(equipment),
                  ),
                ),
          ],
          onChanged: ready
              ? (value) => setState(() => _equipment = value ?? '')
              : null,
        ),
        const SizedBox(height: 16),
        if (widget.busy)
          const LinearProgressIndicator(semanticsLabel: 'Loading workouts'),
        if (widget.error != null) ...[
          Semantics(liveRegion: true, child: Text(widget.error!)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: widget.busy ? null : widget.onRetry,
              child: const Text('Retry'),
            ),
          ),
        ],
        if (widget.message != null)
          Semantics(liveRegion: true, child: Text(widget.message!)),
        if (match?.message != null)
          Semantics(liveRegion: true, child: Text(match!.message!)),
        if (suggestion != null && !_suggestionHidden)
          Card(
            key: const ValueKey('gear-match'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Suggested plan',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    suggestion.plan.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    widget.preferredEquipment == 'No preference'
                        ? 'Equipment match: skipped (no preference)'
                        : 'Equipment match: +${suggestion.equipmentPoints}',
                  ),
                  Text(
                    match!.lastWorkoutId == null
                        ? 'Recent workout: skipped (no finished history)'
                        : 'Different from your last finished workout: +${suggestion.recentPoints}',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () => widget.onOpenPlan(suggestion.plan),
                        child: const Text('View plan'),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _suggestionHidden = true),
                        child: const Text('Not now'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (ready && widget.plans.isEmpty)
          const Text('No plans yet. Add a plan to get started.'),
        if (ready && widget.plans.isNotEmpty && visible.isEmpty) ...[
          const Text('No plans match this equipment.'),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _equipment = ''),
              child: const Text('Clear filter'),
            ),
          ),
        ],
        for (final plan in visible)
          PlanCard(
            key: ValueKey(plan.id),
            name: plan.title,
            equipment: plan.equipmentTag,
            onOpen: ready ? () => widget.onOpenPlan(plan) : null,
            onEdit: ready ? () => widget.onEditPlan(plan) : null,
          ),
      ],
    );
  }
}
