import 'package:flutter/material.dart';

import '../data/training_log_store.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/log_editor_dialog.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.store, this.plans = const []});

  final TrainingLogStore? store;
  final List<WorkoutReference> plans;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<TrainingEntry> _entries = [];
  bool _busy = false;
  bool _loaded = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.store == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final entries = await widget.store!.readAll();
      if (!mounted) return;
      entries.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
      setState(() {
        _entries = entries;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load history. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([TrainingEntry? entry]) async {
    if (_busy || widget.store == null) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LogEditorDialog(
        store: widget.store!,
        plans: widget.plans,
        entries: _entries,
        entry: entry,
      ),
    );
    if (!mounted || saved != true) return;
    setState(() => _message = 'History saved.');
    await _load();
  }

  Future<void> _delete(TrainingEntry entry) async {
    if (_busy || entry.id == null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Delete this set?',
      message:
          '${entry.exerciseLabel}: ${entry.reps} reps. Deleting the last set of a finished workout also removes that workout from the total.',
      action: 'Delete set',
    );
    if (!mounted || !confirmed || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.store!.delete(entry.id!);
      if (!mounted) return;
      setState(() => _message = 'Set deleted.');
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not delete this set. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && _error == null) await _load();
  }

  String _planTitle(int id) {
    for (final plan in widget.plans) {
      if (plan.id == id) return plan.title;
    }
    return 'Workout plan $id';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.store == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'History is not available yet. Saved workouts will appear once tracking is connected.',
        ),
      );
    }
    final groups = <String, List<TrainingEntry>>{};
    for (final entry in _entries) {
      groups.putIfAbsent(entry.sessionKey, () => []).add(entry);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_loaded)
          Text(
            'Finished workouts: ${finishedSessionCount(_entries)}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed:
                  _busy || !_loaded || _error != null || widget.plans.isEmpty
                  ? null
                  : () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Add entry'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : _load,
              child: const Text('Refresh'),
            ),
          ],
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(
              semanticsLabel: 'Loading or saving history',
            ),
          ),
        if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
        if (_message != null)
          Semantics(liveRegion: true, child: Text(_message!)),
        if (_loaded && _entries.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('No workout history yet.'),
          ),
        for (final group in groups.values)
          Card(
            margin: const EdgeInsets.only(top: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _planTitle(group.first.workoutId),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    group.first.loggedAt.toLocal().toString().split('.').first,
                  ),
                  Text(
                    group.first.sessionFinished
                        ? 'Finished workout'
                        : 'Unfinished workout',
                  ),
                  for (final entry in group)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${entry.exerciseLabel} · ${entry.reps} reps'),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Semantics(
                                label: 'Edit ${entry.exerciseLabel}',
                                child: OutlinedButton(
                                  onPressed:
                                      _busy ||
                                          _error != null ||
                                          entry.id == null
                                      ? null
                                      : () => _edit(entry),
                                  child: const Text('Edit'),
                                ),
                              ),
                              Semantics(
                                label: 'Delete ${entry.exerciseLabel}',
                                child: TextButton(
                                  onPressed:
                                      _busy ||
                                          _error != null ||
                                          entry.id == null
                                      ? null
                                      : () => _delete(entry),
                                  child: const Text('Delete'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
