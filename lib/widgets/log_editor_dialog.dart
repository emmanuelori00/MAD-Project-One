import 'package:flutter/material.dart';

import '../data/training_log_store.dart';
import 'confirmation_dialog.dart';

class LogEditorDialog extends StatefulWidget {
  const LogEditorDialog({
    super.key,
    required this.store,
    required this.plans,
    required this.entries,
    this.entry,
  });

  final TrainingLogStore store;
  final List<WorkoutReference> plans;
  final List<TrainingEntry> entries;
  final TrainingEntry? entry;

  @override
  State<LogEditorDialog> createState() => _LogEditorDialogState();
}

class _LogEditorDialogState extends State<LogEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final _exercise = TextEditingController(
    text: widget.entry?.exerciseLabel,
  );
  late final _reps = TextEditingController(text: widget.entry?.reps.toString());
  int? _workoutId;
  String? _existingSession;
  final _newSession = newSessionKey();
  bool _busy = false;
  bool _allowClose = false;
  bool _confirming = false;
  String? _error;

  bool get _dirty =>
      _exercise.text != (widget.entry?.exerciseLabel ?? '') ||
      _reps.text != (widget.entry?.reps.toString() ?? '') ||
      _workoutId != null;

  @override
  void dispose() {
    _exercise.dispose();
    _reps.dispose();
    super.dispose();
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
    if (mounted && discard) _close(false);
  }

  void _close(bool saved) {
    setState(() => _allowClose = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(saved);
    });
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final original = widget.entry;
      if (original != null) {
        await widget.store.correct(
          original.id!,
          exerciseLabel: _exercise.text.trim(),
          reps: int.parse(_reps.text.trim()),
        );
      } else {
        final session = _existingSession == null
            ? null
            : widget.entries.firstWhere(
                (entry) => entry.sessionKey == _existingSession,
              );
        await widget.store.add(
          TrainingEntry(
            workoutId: _workoutId!,
            sessionKey: session?.sessionKey ?? _newSession,
            exerciseLabel: _exercise.text.trim(),
            reps: int.parse(_reps.text.trim()),
            loggedAt: DateTime.now().toUtc(),
            sessionFinished: session?.sessionFinished ?? true,
          ),
        );
      }
      if (mounted) _close(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save this entry. Your changes are still here. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = <String, TrainingEntry>{};
    for (final entry in widget.entries) {
      if (entry.workoutId == _workoutId) sessions[entry.sessionKey] = entry;
    }
    return PopScope(
      canPop: _allowClose,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: AlertDialog(
        title: Text(
          widget.entry == null ? 'Add history entry' : 'Edit history entry',
        ),
        scrollable: true,
        content: SizedBox(
          width: 420,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.entry == null) ...[
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Workout plan',
                    ),
                    isExpanded: true,
                    items: widget.plans
                        .map(
                          (plan) => DropdownMenuItem(
                            value: plan.id,
                            child: Text(plan.title),
                          ),
                        )
                        .toList(),
                    validator: (value) =>
                        value == null ? 'Choose a saved plan.' : null,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() {
                            _workoutId = value;
                            _existingSession = null;
                          }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_workoutId),
                    initialValue: '',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Workout session',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('New finished workout'),
                      ),
                      ...sessions.entries.map(
                        (session) => DropdownMenuItem(
                          value: session.key,
                          child: Text(
                            '${session.value.loggedAt.toLocal().toString().split('.').first} · ${session.value.sessionFinished ? 'Finished' : 'Unfinished'}',
                          ),
                        ),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(
                            () => _existingSession = value == '' ? null : value,
                          ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose an existing session when adding another set from the same workout.',
                  ),
                ],
                TextFormField(
                  controller: _exercise,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'Exercise name'),
                  validator: validateExercise,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reps,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'Repetitions'),
                  keyboardType: TextInputType.number,
                  validator: validateReps,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Semantics(liveRegion: true, child: Text(_error!)),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : _cancel,
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save entry'),
          ),
        ],
      ),
    );
  }
}
