import 'dart:async';

import 'package:movement_quest/data/app_settings.dart';
import 'package:movement_quest/data/training_log_store.dart';
import 'package:movement_quest/data/workout_plan.dart';
import 'package:movement_quest/data/workout_plan_store.dart';

class FakePlanStore implements WorkoutPlanStore {
  FakePlanStore({this.logs});

  final FakeLogStore? logs;
  final plans = <WorkoutPlan>[];
  bool failRead = false;
  bool failWrite = false;
  Completer<void>? pending;
  int adds = 0;
  int updates = 0;
  int deletes = 0;
  int _id = 0;

  Future<void> _write() async {
    if (pending != null) await pending!.future;
    if (failWrite) throw StateError('write failed');
  }

  WorkoutPlan _saved(WorkoutPlan plan, int id) => WorkoutPlan(
    id: id,
    title: plan.title.trim(),
    equipmentTag: plan.equipmentTag,
    planNote: plan.planNote,
    effortPreference: plan.effortPreference,
  );

  @override
  Future<List<WorkoutPlan>> readPlans() async {
    if (failRead) throw StateError('read failed');
    return [...plans];
  }

  @override
  Future<int> addPlan(WorkoutPlan plan) async {
    adds++;
    await _write();
    final id = ++_id;
    plans.add(_saved(plan, id));
    return id;
  }

  @override
  Future<void> updatePlan(WorkoutPlan plan) async {
    updates++;
    await _write();
    final index = plans.indexWhere((saved) => saved.id == plan.id);
    if (index < 0) throw StateError('missing plan');
    plans[index] = _saved(plan, plan.id!);
  }

  @override
  Future<void> deletePlan(int id) async {
    deletes++;
    await _write();
    if (logs?.entries.any((entry) => entry.workoutId == id) ?? false) {
      throw const PlanHasLogsException();
    }
    plans.removeWhere((plan) => plan.id == id);
  }
}

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
