import 'package:flutter/material.dart';

import '../data/app_settings.dart';
import '../data/workout_plan.dart';
import '../data/workout_plan_store.dart';
import '../widgets/confirmation_dialog.dart';

class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({
    super.key,
    required this.store,
    required this.defaults,
    this.plan,
  });

  final WorkoutPlanStore store;
  final AppSettings defaults;
  final WorkoutPlan? plan;

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.plan?.title ?? '');
  late final _notes = TextEditingController(text: widget.plan?.planNote ?? '');
  late final String? _initialEquipment =
      widget.plan?.equipmentTag ??
      (widget.defaults.equipment == 'No preference'
          ? null
          : widget.defaults.equipment);
  late final _initialEffort =
      widget.plan?.effortPreference ?? widget.defaults.defaultEffort;
  late String? _equipment = _initialEquipment;
  late int _effort = _initialEffort;
  bool _busy = false;
  bool _confirming = false;
  bool _allowClose = false;
  String? _error;

  bool get _dirty =>
      _name.text != (widget.plan?.title ?? '') ||
      _notes.text != (widget.plan?.planNote ?? '') ||
      _equipment != _initialEquipment ||
      _effort != _initialEffort;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _close([WorkoutPlan? saved]) {
    setState(() => _allowClose = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(saved);
    });
  }

  Future<void> _cancel() async {
    if (_busy || _confirming) return;
    _confirming = true;
    final discard =
        !_dirty ||
        await confirmAction(
          context,
          title: 'Discard changes?',
          message: 'Your unsaved changes will be lost.',
          action: 'Discard',
        );
    _confirming = false;
    if (mounted && discard) _close();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final plan = WorkoutPlan(
      id: widget.plan?.id,
      title: _name.text.trim(),
      equipmentTag: _equipment!,
      planNote: _notes.text,
      effortPreference: _effort,
    );
    try {
      final int id;
      if (plan.id == null) {
        id = await widget.store.addPlan(plan);
      } else {
        await widget.store.updatePlan(plan);
        id = plan.id!;
      }
      if (!mounted) return;
      _close(
        WorkoutPlan(
          id: id,
          title: plan.title,
          equipmentTag: plan.equipmentTag,
          planNote: plan.planNote,
          effortPreference: plan.effortPreference,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save this plan. Your changes are still here. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowClose,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.plan == null ? 'Add plan' : 'Edit plan'),
        ),
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'Plan name'),
                  validator: validatePlanTitle,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _equipment,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Equipment'),
                  items: equipmentChoices
                      .skip(1)
                      .map(
                        (equipment) => DropdownMenuItem(
                          value: equipment,
                          child: Text(equipment),
                        ),
                      )
                      .toList(),
                  validator: (value) =>
                      value == null ? 'Choose equipment for this plan.' : null,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _equipment = value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notes,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                  minLines: 2,
                  maxLines: 5,
                  validator: validatePlanNote,
                ),
                const SizedBox(height: 16),
                Text('Effort: $_effort of 5'),
                Semantics(
                  label: 'Plan effort',
                  child: Slider(
                    value: _effort.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '$_effort of 5',
                    semanticFormatterCallback: (value) =>
                        '${value.round()} of 5',
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _effort = value.round()),
                  ),
                ),
                if (_error != null)
                  Semantics(liveRegion: true, child: Text(_error!)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: Text(_busy ? 'Saving…' : 'Save plan'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : _cancel,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
