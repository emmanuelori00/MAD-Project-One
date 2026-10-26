import 'dart:async';

import 'package:movement_quest/data/app_settings.dart';
import 'package:movement_quest/data/training_log_store.dart';

class FakeSettingsStore implements SettingsStore {
  AppSettings value = const AppSettings();
  bool failLoad = false;
  bool failSave = false;
  Completer<void>? pending;
  int saves = 0;

  @override
  Future<AppSettings> load() async {
    if (failLoad) throw StateError('load failed');
    return value;
  }

  @override
  Future<void> save(AppSettings settings) async {
    saves++;
    if (pending != null) await pending!.future;
    if (failSave) throw StateError('save failed');
    value = settings;
  }
}

class FakeLogStore implements TrainingLogStore {
  final entries = <TrainingEntry>[];
  bool failWrite = false;
  bool failRead = false;
  Completer<void>? pending;
  int adds = 0;
  int finishes = 0;
  int deletes = 0;
  int _id = 0;

  Future<void> _write() async {
    if (pending != null) await pending!.future;
    if (failWrite) throw StateError('write failed');
  }

  @override
  Future<List<TrainingEntry>> readAll() async {
    if (failRead) throw StateError('read failed');
    return [...entries];
  }

  @override
  Future<void> add(TrainingEntry entry) async {
    adds++;
    await _write();
    entries.add(
      TrainingEntry(
        id: ++_id,
        workoutId: entry.workoutId,
        sessionKey: entry.sessionKey,
        exerciseLabel: entry.exerciseLabel,
        reps: entry.reps,
        loggedAt: entry.loggedAt,
        sessionFinished: entry.sessionFinished,
      ),
    );
  }

  @override
  Future<void> correct(
    int id, {
    required String exerciseLabel,
    required int reps,
  }) async {
    await _write();
    final index = entries.indexWhere((entry) => entry.id == id);
    final old = entries[index];
    entries[index] = TrainingEntry(
      id: old.id,
      workoutId: old.workoutId,
      sessionKey: old.sessionKey,
      exerciseLabel: exerciseLabel,
      reps: reps,
      loggedAt: old.loggedAt,
      sessionFinished: old.sessionFinished,
    );
  }

  @override
  Future<void> delete(int id) async {
    deletes++;
    await _write();
    entries.removeWhere((entry) => entry.id == id);
  }

  @override
  Future<void> finishSession(String sessionKey) async {
    finishes++;
    await _write();
    for (var i = 0; i < entries.length; i++) {
      final old = entries[i];
      if (old.sessionKey != sessionKey) continue;
      entries[i] = TrainingEntry(
        id: old.id,
        workoutId: old.workoutId,
        sessionKey: old.sessionKey,
        exerciseLabel: old.exerciseLabel,
        reps: old.reps,
        loggedAt: old.loggedAt,
        sessionFinished: true,
      );
    }
  }
}
