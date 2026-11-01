import 'package:flutter/material.dart';

import '../data/training_log_store.dart';
import '../data/workout_plan.dart';
import '../data/workout_plan_store.dart';
import '../widgets/confirmation_dialog.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({
    super.key,
    required this.planName,
    required this.equipment,
    this.workoutId,
    this.logStore,
    this.onEdit,
    this.planStore,
    this.planNote = '',
    this.effortPreference = 3,
  });

  final String planName;
  final String equipment;
  final int? workoutId;
  final TrainingLogStore? logStore;
  final Future<WorkoutPlan?> Function()? onEdit;
  final WorkoutPlanStore? planStore;
  final String planNote;
  final int effortPreference;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final _form = GlobalKey<FormState>();
  final _exercise = TextEditingController();
  final _reps = TextEditingController();
  String? _sessionKey;
  String? _message;
  int _savedSets = 0;
  bool _finished = false;
  bool _busy = false;
  bool _allowExit = false;
  bool _confirming = false;
  WorkoutPlan? _editedPlan;

  String get _planName => _editedPlan?.title ?? widget.planName;
  String get _equipment => _editedPlan?.equipmentTag ?? widget.equipment;
  String get _notes => _editedPlan?.planNote ?? widget.planNote;
  int get _effort => _editedPlan?.effortPreference ?? widget.effortPreference;

  bool get _active => _sessionKey != null && !_finished;
  bool get _available => widget.workoutId != null && widget.logStore != null;

  @override
  void dispose() {
    _exercise.dispose();
    _reps.dispose();
    super.dispose();
  }

  void _start() {
    if (!_available || _busy || _active) return;
    setState(() {
      _sessionKey = newSessionKey();
      _savedSets = 0;
      _finished = false;
      _message = 'Workout started. Save your first set below.';
      _exercise.clear();
      _reps.clear();
    });
  }

  Future<void> _editPlan() async {
    if (_active || _busy || widget.onEdit == null) return;
    setState(() => _busy = true);
    try {
      final saved = await widget.onEdit!();
      if (mounted && saved != null) {
        setState(() {
          _editedPlan = saved;
          _message = 'Plan saved.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePlan() async {
    if (_active ||
        _busy ||
        _confirming ||
        widget.planStore == null ||
        widget.workoutId == null) {
      return;
    }
    _confirming = true;
    final confirmed = await confirmAction(
      context,
      title: 'Delete this plan?',
      message: 'Remove "$_planName"? Plans with saved sets cannot be deleted.',
      action: 'Delete plan',
    );
    _confirming = false;
    if (!mounted || !confirmed) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.planStore!.deletePlan(widget.workoutId!);
      if (!mounted) return;
      setState(() => _allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } on PlanHasLogsException catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not delete this plan. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveSet() async {
    if (_busy || !_active || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.logStore!.add(
        TrainingEntry(
          workoutId: widget.workoutId!,
          sessionKey: _sessionKey!,
          exerciseLabel: _exercise.text.trim(),
          reps: int.parse(_reps.text.trim()),
          loggedAt: DateTime.now().toUtc(),
          sessionFinished: false,
        ),
      );
      if (!mounted) return;
      setState(() {
        _savedSets++;
        _exercise.clear();
        _reps.clear();
        _form.currentState!.reset();
        _message = 'Set saved.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Could not save this set. Your input is still here. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (_busy || !_active || _savedSets == 0) return;
    if (_exercise.text.trim().isNotEmpty || _reps.text.trim().isNotEmpty) {
      setState(
        () => _message = 'Save this set or clear both fields before finishing.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.logStore!.finishSession(_sessionKey!);
      if (mounted) {
        setState(() {
          _finished = true;
          _message = 'Workout finished. Your saved sets count as one workout.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not finish this workout. Your saved sets are kept. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave({bool reset = false}) async {
    if (_busy || _confirming) return;
    _confirming = true;
    final confirmed =
        !_active ||
        await confirmAction(
          context,
          title: reset ? 'Reset workout?' : 'Leave workout?',
          message: 'Saved sets stay in history as unfinished. Any unsaved input will be discarded.',
          action: reset ? 'Reset workout' : 'Leave workout',
        );
    _confirming = false;
    if (!mounted || !confirmed) return;
    if (reset) {
      setState(() {
        _sessionKey = null;
        _savedSets = 0;
        _finished = false;
        _exercise.clear();
        _reps.clear();
        _message = 'Workout reset. Saved history was kept.';
      });
    } else {
      setState(() => _allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowExit || (!_active && !_busy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Current workout')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(_planName, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('Equipment: $_equipment'),
              Text('Effort: $_effort of 5'),
              if (_notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_notes),
              ],
              const SizedBox(height: 16),
              if (!_available)
                const Text(
                  'Example plan — not saved. Tracking will be available when saved plans are connected.',
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: _active || _busy || widget.onEdit == null
                        ? null
                        : _editPlan,
                    child: const Text('Edit plan'),
                  ),
                  if (widget.planStore != null && widget.workoutId != null)
                    TextButton(
                      onPressed: _active || _busy ? null : _deletePlan,
                      child: const Text('Delete plan'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Saved sets this workout: $_savedSets'),
              const SizedBox(height: 12),
              if (!_active)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: _available && !_busy ? _start : null,
                    child: Text(
                      _finished ? 'Start another workout' : 'Start workout',
                    ),
                  ),
                ),
              if (_active) ...[
                Form(
                  key: _form,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _exercise,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Exercise name',
                        ),
                        validator: validateExercise,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _reps,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Repetitions',
                        ),
                        keyboardType: TextInputType.number,
                        validator: validateReps,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : _saveSet,
                      child: const Text('Save set'),
                    ),
                    FilledButton.tonal(
                      onPressed: _busy || _savedSets == 0 ? null : _finish,
                      child: const Text('Finish workout'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _leave(reset: true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ],
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('Saving…'),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(liveRegion: true, child: Text(_message!)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
