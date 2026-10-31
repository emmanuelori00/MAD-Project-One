import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/data/movement_quest_database.dart';
import 'package:movement_quest/data/training_log_store.dart';
import 'package:movement_quest/data/workout_plan.dart';
import 'package:movement_quest/data/workout_plan_store.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

WorkoutPlan plan({
  int? id,
  String title = 'Dumbbell day',
  String equipment = 'Dumbbells',
  String note = '',
  int effort = 3,
}) => WorkoutPlan(
  id: id,
  title: title,
  equipmentTag: equipment,
  planNote: note,
  effortPreference: effort,
);

TrainingEntry entry(
  int workoutId, {
  int? id,
  String session = 'workout-1',
  String exercise = 'Squat',
  int reps = 10,
  bool finished = false,
  DateTime? time,
}) => TrainingEntry(
  id: id,
  workoutId: workoutId,
  sessionKey: session,
  exerciseLabel: exercise,
  reps: reps,
  loggedAt: time ?? DateTime.utc(2026, 10, 31, 14),
  sessionFinished: finished,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory folder;
  late MovementQuestDatabase store;

  setUp(() async {
    final parent = await Directory('.dart_tool').create(recursive: true);
    folder = await parent.createTemp('movement_quest_database_test_');
    store = MovementQuestDatabase(
      factory: databaseFactoryFfi,
      databasePath: join(folder.path, 'test.db'),
    );
  });

  tearDown(() async {
    await store.close();
    await folder.delete(recursive: true);
  });

  test('plans can be created, read, edited, and deleted', () async {
    expect(await store.readPlans(), isEmpty);
    final id = await store.addPlan(plan(title: '  First plan  '));
    final saved = (await store.readPlans()).single;
    expect(saved.id, id);
    expect(saved.title, 'First plan');
    expect(saved.equipmentTag, 'Dumbbells');

    await store.updatePlan(
      plan(id: id, title: 'Updated plan', note: 'Keep it simple', effort: 4),
    );
    final updated = (await store.readPlans()).single;
    expect(updated.title, 'Updated plan');
    expect(updated.planNote, 'Keep it simple');
    expect(updated.effortPreference, 4);
    await store.deletePlan(id);
    expect(await store.readPlans(), isEmpty);
  });

  test(
    'invalid plans and missing plan updates leave saved data alone',
    () async {
      final id = await store.addPlan(plan());
      for (final invalid in [
        plan(title: '   '),
        plan(title: 'a' * 61),
        plan(equipment: 'No preference'),
        plan(note: 'a' * 501),
        plan(effort: 0),
        plan(effort: 6),
        plan(id: id),
      ]) {
        await expectLater(store.addPlan(invalid), throwsArgumentError);
      }
      await expectLater(
        store.updatePlan(plan(id: id, title: '')),
        throwsArgumentError,
      );
      await expectLater(store.updatePlan(plan(id: id + 1)), throwsStateError);
      expect((await store.readPlans()).single.title, 'Dumbbell day');
    },
  );

  test(
    'set corrections preserve the plan, session, time, and status',
    () async {
      final id = await store.addPlan(plan());
      final originalTime = DateTime.parse('2026-10-31T10:00:00-04:00');
      await store.add(entry(id, exercise: '  Squat  ', time: originalTime));
      final saved = (await store.readAll()).single;
      expect(saved.exerciseLabel, 'Squat');
      expect(saved.loggedAt.isUtc, isTrue);
      expect(saved.loggedAt, originalTime.toUtc());

      await store.correct(saved.id!, exerciseLabel: '  Lunge  ', reps: 12);
      final corrected = (await store.readAll()).single;
      expect(corrected.id, saved.id);
      expect(corrected.exerciseLabel, 'Lunge');
      expect(corrected.reps, 12);
      expect(corrected.workoutId, saved.workoutId);
      expect(corrected.sessionKey, saved.sessionKey);
      expect(corrected.loggedAt, saved.loggedAt);
      expect(corrected.sessionFinished, saved.sessionFinished);
      await store.delete(saved.id!);
      expect(await store.readAll(), isEmpty);
    },
  );

  test('invalid sets and orphaned logs are rejected', () async {
    final id = await store.addPlan(plan());
    for (final invalid in [
      entry(id, exercise: '   '),
      entry(id, exercise: 'a' * 61),
      entry(id, reps: 0),
      entry(id, reps: -1),
      entry(id, session: '  '),
      entry(0),
      entry(id, id: 1),
    ]) {
      await expectLater(store.add(invalid), throwsArgumentError);
    }
    await expectLater(
      store.add(entry(id + 1)),
      throwsA(isA<DatabaseException>()),
    );
    expect(await store.readAll(), isEmpty);
    await store.add(entry(id));
    expect(await store.readAll(), hasLength(1));
  });

  test('a session cannot mix plans or finished states', () async {
    final first = await store.addPlan(plan());
    final second = await store.addPlan(plan(title: 'Other plan'));
    await store.add(entry(first));
    await expectLater(store.add(entry(second)), throwsStateError);
    await expectLater(
      store.add(entry(first, finished: true)),
      throwsStateError,
    );
    expect(await store.readAll(), hasLength(1));
    await store.add(entry(first, reps: 8));
    expect(await store.readAll(), hasLength(2));
  });

  test('competing writes cannot create a mixed session', () async {
    final first = await store.addPlan(plan());
    final second = await store.addPlan(plan(title: 'Other plan'));
    Future<bool> tryAdd(int id) async {
      try {
        await store.add(entry(id));
        return true;
      } on StateError {
        return false;
      }
    }

    final results = await Future.wait([tryAdd(first), tryAdd(second)]);
    expect(results.where((saved) => saved), hasLength(1));
    expect(await store.readAll(), hasLength(1));
  });

  test('finishing twice keeps three sets as one finished workout', () async {
    final id = await store.addPlan(plan());
    for (var i = 0; i < 3; i++) {
      await store.add(entry(id, reps: 10 + i));
    }
    await store.add(entry(id, session: 'workout-2'));
    await Future.wait([
      store.finishSession('workout-1'),
      store.finishSession('workout-1'),
    ]);
    final logs = await store.readAll();
    expect(logs, hasLength(4));
    expect(finishedSessionCount(logs), 1);
    expect(
      logs.where((log) => log.sessionKey == 'workout-1'),
      everyElement(
        isA<TrainingEntry>().having(
          (log) => log.sessionFinished,
          'finished',
          isTrue,
        ),
      ),
    );
    expect(
      logs.singleWhere((log) => log.sessionKey == 'workout-2').sessionFinished,
      isFalse,
    );
    await expectLater(store.add(entry(id)), throwsStateError);
    await store.add(entry(id, finished: true));
    expect(finishedSessionCount(await store.readAll()), 1);
  });

  test('empty sessions cannot be finished', () async {
    await expectLater(store.finishSession(''), throwsArgumentError);
    await expectLater(store.finishSession('missing'), throwsStateError);
    expect(await store.readAll(), isEmpty);
  });

  test('plans stay protected until their last saved set is removed', () async {
    final id = await store.addPlan(plan());
    await store.add(entry(id, finished: true));
    await store.add(entry(id, finished: true, reps: 8));
    await expectLater(
      store.deletePlan(id),
      throwsA(isA<PlanHasLogsException>()),
    );
    final db = await store.database;
    await expectLater(
      db.delete('WorkoutPlan', where: 'id = ?', whereArgs: [id]),
      throwsA(isA<DatabaseException>()),
    );
    final logs = await store.readAll();
    expect(logs, hasLength(2));
    await store.delete(logs.first.id!);
    expect(finishedSessionCount(await store.readAll()), 1);
    await expectLater(
      store.deletePlan(id),
      throwsA(isA<PlanHasLogsException>()),
    );
    await store.delete(logs.last.id!);
    expect(finishedSessionCount(await store.readAll()), 0);
    await store.deletePlan(id);
    expect(await store.readPlans(), isEmpty);
  });

  test(
    'invalid corrections and missing records do not change history',
    () async {
      final id = await store.addPlan(plan());
      await store.add(entry(id));
      final logId = (await store.readAll()).single.id!;
      await expectLater(
        store.correct(logId, exerciseLabel: '', reps: 10),
        throwsArgumentError,
      );
      await expectLater(
        store.correct(logId, exerciseLabel: 'Squat', reps: 0),
        throwsArgumentError,
      );
      await expectLater(
        store.correct(logId + 1, exerciseLabel: 'Squat', reps: 10),
        throwsStateError,
      );
      await expectLater(store.delete(logId + 1), throwsStateError);
      final saved = (await store.readAll()).single;
      expect(saved.reps, 10);
      expect(saved.exerciseLabel, 'Squat');
    },
  );

  test(
    'plans, finished sessions, and unfinished sets survive reopening',
    () async {
      final id = await store.addPlan(plan(note: 'Saved note', effort: 5));
      await store.add(entry(id));
      await store.finishSession('workout-1');
      await store.add(entry(id, session: 'unfinished'));
      await store.close();
      store = MovementQuestDatabase(
        factory: databaseFactoryFfi,
        databasePath: join(folder.path, 'test.db'),
      );

      final savedPlan = (await store.readPlans()).single;
      expect(savedPlan.id, id);
      expect(savedPlan.planNote, 'Saved note');
      expect(savedPlan.effortPreference, 5);
      final logs = await store.readAll();
      expect(logs, hasLength(2));
      expect(finishedSessionCount(logs), 1);
      expect(
        logs
            .singleWhere((log) => log.sessionKey == 'unfinished')
            .sessionFinished,
        isFalse,
      );
      await expectLater(
        store.deletePlan(id),
        throwsA(isA<PlanHasLogsException>()),
      );
    },
  );

  test(
    'history sorts by actual time including sub-millisecond differences',
    () async {
      final id = await store.addPlan(plan());
      final time = DateTime.utc(2026, 10, 31, 14);
      await store.add(entry(id, reps: 1, time: time));
      await store.add(
        entry(id, reps: 2, time: time.add(const Duration(microseconds: 1))),
      );
      await store.add(entry(id, reps: 3, time: time));
      expect((await store.readAll()).map((log) => log.reps), [2, 3, 1]);
    },
  );
}
