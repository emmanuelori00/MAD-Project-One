import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'training_log_store.dart';
import 'workout_plan.dart';
import 'workout_plan_store.dart';

class MovementQuestDatabase implements WorkoutPlanStore, TrainingLogStore {
  MovementQuestDatabase({DatabaseFactory? factory, this.databasePath})
    : _factory = factory ?? databaseFactory;

  final DatabaseFactory _factory;
  final String? databasePath;
  Future<Database>? _opening;

  Future<Database> get database async {
    final opening = _opening ??= _open();
    try {
      return await opening;
    } catch (_) {
      if (identical(_opening, opening)) _opening = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    final pathToDatabase =
        databasePath ??
        join(await _factory.getDatabasesPath(), 'movement_quest.db');

    return _factory.openDatabase(
      pathToDatabase,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE WorkoutPlan (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL
                CHECK(length(trim(title)) BETWEEN 1 AND 60),
              equipmentTag TEXT NOT NULL
                CHECK(equipmentTag IN (
                  'No equipment', 'Dumbbells', 'Resistance band', 'Other'
                )),
              planNote TEXT NOT NULL DEFAULT ''
                CHECK(length(planNote) <= 500),
              effortPreference INTEGER NOT NULL
                CHECK(effortPreference BETWEEN 1 AND 5)
            )
          ''');
          await db.execute('''
            CREATE TABLE TrainingLog (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              workoutId INTEGER NOT NULL,
              sessionKey TEXT NOT NULL
                CHECK(length(trim(sessionKey)) > 0),
              exerciseLabel TEXT NOT NULL
                CHECK(length(trim(exerciseLabel)) BETWEEN 1 AND 60),
              reps INTEGER NOT NULL
                CHECK(reps > 0),
              loggedAt TEXT NOT NULL,
              sessionFinished INTEGER NOT NULL DEFAULT 0
                CHECK(sessionFinished IN (0, 1)),
              FOREIGN KEY(workoutId)
                REFERENCES WorkoutPlan(id)
                ON DELETE RESTRICT
            )
          ''');
        },
      ),
    );
  }

  @override
  Future<List<WorkoutPlan>> readPlans() async {
    final db = await database;
    final rows = await db.query('WorkoutPlan', orderBy: 'id ASC');
    return rows.map(WorkoutPlan.fromMap).toList();
  }

  @override
  Future<int> addPlan(WorkoutPlan plan) async {
    if (!plan.isValid || plan.id != null) {
      throw ArgumentError('Enter a valid new workout plan.');
    }
    final db = await database;
    return db.insert('WorkoutPlan', plan.toMap());
  }

  @override
  Future<void> updatePlan(WorkoutPlan plan) async {
    if (!plan.isValid || plan.id == null) {
      throw ArgumentError('Enter a valid saved workout plan.');
    }
    final db = await database;
    final count = await db.update(
      'WorkoutPlan',
      plan.toMap(),
      where: 'id = ?',
      whereArgs: [plan.id],
    );
    if (count != 1) throw StateError('This plan no longer exists.');
  }

  @override
  Future<void> deletePlan(int id) async {
    if (id <= 0) throw ArgumentError('Choose a saved workout plan.');
    final db = await database;
    await db.transaction((txn) async {
      final logs = await txn.query(
        'TrainingLog',
        columns: ['id'],
        where: 'workoutId = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (logs.isNotEmpty) throw const PlanHasLogsException();

      final count = await txn.delete(
        'WorkoutPlan',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count != 1) throw StateError('This plan no longer exists.');
    });
  }

  @override
  Future<List<TrainingEntry>> readAll() async {
    final db = await database;
    final rows = await db.query('TrainingLog');
    final entries = rows.map((row) {
      return TrainingEntry(
        id: row['id'] as int,
        workoutId: row['workoutId'] as int,
        sessionKey: row['sessionKey'] as String,
        exerciseLabel: row['exerciseLabel'] as String,
        reps: row['reps'] as int,
        loggedAt: DateTime.parse(row['loggedAt'] as String).toUtc(),
        sessionFinished: row['sessionFinished'] == 1,
      );
    }).toList();
    entries.sort((a, b) {
      final timeOrder = b.loggedAt.compareTo(a.loggedAt);
      return timeOrder != 0 ? timeOrder : b.id!.compareTo(a.id!);
    });
    return entries;
  }

  @override
  Future<void> add(TrainingEntry entry) async {
    if (entry.id != null ||
        entry.workoutId <= 0 ||
        entry.sessionKey.trim().isEmpty ||
        validateExercise(entry.exerciseLabel) != null ||
        entry.reps <= 0) {
      throw ArgumentError('Enter a valid new workout set.');
    }
    final db = await database;
    await db.transaction((txn) async {
      final session = await txn.query(
        'TrainingLog',
        columns: ['workoutId', 'sessionFinished'],
        where: 'sessionKey = ?',
        whereArgs: [entry.sessionKey],
      );
      final finished = entry.sessionFinished ? 1 : 0;
      if (session.any(
        (row) =>
            row['workoutId'] != entry.workoutId ||
            row['sessionFinished'] != finished,
      )) {
        throw StateError('Use the same plan and status for this session.');
      }
      await txn.insert('TrainingLog', {
        'workoutId': entry.workoutId,
        'sessionKey': entry.sessionKey,
        'exerciseLabel': entry.exerciseLabel.trim(),
        'reps': entry.reps,
        'loggedAt': entry.loggedAt.toUtc().toIso8601String(),
        'sessionFinished': finished,
      });
    });
  }

  @override
  Future<void> correct(
    int id, {
    required String exerciseLabel,
    required int reps,
  }) async {
    if (id <= 0 || validateExercise(exerciseLabel) != null || reps <= 0) {
      throw ArgumentError('Enter a valid exercise name and rep count.');
    }
    final db = await database;
    final count = await db.update(
      'TrainingLog',
      {'exerciseLabel': exerciseLabel.trim(), 'reps': reps},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count != 1) throw StateError('This set no longer exists.');
  }

  @override
  Future<void> delete(int id) async {
    if (id <= 0) throw ArgumentError('Choose a saved set.');
    final db = await database;
    final count = await db.delete(
      'TrainingLog',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count != 1) throw StateError('This set no longer exists.');
  }

  @override
  Future<void> finishSession(String sessionKey) async {
    if (sessionKey.trim().isEmpty) {
      throw ArgumentError('Choose a workout session.');
    }

    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'TrainingLog',
        columns: ['id'],
        where: 'sessionKey = ?',
        whereArgs: [sessionKey],
        limit: 1,
      );

      if (rows.isEmpty) {
        throw StateError('Save at least one set before finishing.');
      }

      await txn.update(
        'TrainingLog',
        {'sessionFinished': 1},
        where: 'sessionKey = ?',
        whereArgs: [sessionKey],
      );
    });
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening == null) return;
    final db = await opening;
    await db.close();
    if (identical(_opening, opening)) _opening = null;
  }
}
