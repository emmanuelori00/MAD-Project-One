import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/data/gear_match.dart';
import 'package:movement_quest/data/training_log_store.dart';
import 'package:movement_quest/data/workout_plan.dart';

WorkoutPlan plan(int id, [String equipment = 'Dumbbells']) => WorkoutPlan(
  id: id,
  title: 'Plan $id',
  equipmentTag: equipment,
  planNote: '',
  effortPreference: 3,
);

TrainingEntry log(
  int workout,
  String session,
  int minute, {
  bool finished = true,
  int reps = 8,
}) => TrainingEntry(
  workoutId: workout,
  sessionKey: session,
  exerciseLabel: 'Rows',
  reps: reps,
  loggedAt: DateTime.utc(2026, 10, 31, 12, minute),
  sessionFinished: finished,
);

void main() {
  test('H1 normal scores and equipment-only comparison', () {
    final result = matchGear(
      plans: [plan(3, 'No equipment'), plan(2), plan(1)],
      entries: [log(2, 'last', 1)],
      equipment: 'Dumbbells',
    );
    expect(result.ranked.map((score) => score.total), [3, 2, 1]);
    expect(result.suggestion!.plan.id, 1);
    expect(result.baseline.first.plan.id, 1);
    expect(result.baseline.map((score) => score.total), [2, 2, 0]);
  });

  test('H2 empty and no finished history', () {
    expect(
      matchGear(plans: [], entries: [], equipment: 'No preference').message,
      'Add a plan first to get a suggestion.',
    );
    final result = matchGear(
      plans: [plan(3), plan(2)],
      entries: [log(2, 'unfinished', 10, finished: false)],
      equipment: 'Dumbbells',
    );
    expect(result.lastWorkoutId, isNull);
    expect(result.suggestion!.plan.id, 2);
    expect(result.ranked.every((score) => score.recentPoints == 0), isTrue);
  });

  test('no preference skips equipment while recent use still counts', () {
    final result = matchGear(
      plans: [plan(2), plan(3, 'Other')],
      entries: [log(2, 'last', 1)],
      equipment: 'No preference',
    );
    expect(result.suggestion!.plan.id, 3);
    expect(result.ranked.every((score) => score.equipmentPoints == 0), isTrue);
    expect(result.baseline.first.plan.id, 2);
    expect(
      matchGear(
        plans: [plan(3), plan(2)],
        entries: [],
        equipment: 'No preference',
      ).suggestion!.total,
      0,
    );
  });

  test('H3 invalid equipment, missing plans and inconsistent sessions', () {
    final cases = [
      matchGear(plans: [plan(1)], entries: [], equipment: 'Bad equipment'),
      matchGear(
        plans: [plan(1, 'Bad equipment')],
        entries: [],
        equipment: 'Dumbbells',
      ),
      matchGear(
        plans: [plan(1)],
        entries: [log(99, 'missing', 1)],
        equipment: 'Dumbbells',
      ),
      matchGear(
        plans: [plan(1), plan(2)],
        entries: [log(1, 'mixed', 1), log(2, 'mixed', 2)],
        equipment: 'Dumbbells',
      ),
      matchGear(
        plans: [plan(1)],
        entries: [log(1, 'mixed', 1), log(1, 'mixed', 2, finished: false)],
        equipment: 'Dumbbells',
      ),
      matchGear(
        plans: [plan(1)],
        entries: [log(1, '', 1)],
        equipment: 'Dumbbells',
      ),
      matchGear(
        plans: [plan(1)],
        entries: [log(1, 'bad reps', 1, reps: 0)],
        equipment: 'Dumbbells',
      ),
      matchGear(plans: [plan(1), plan(1)], entries: [], equipment: 'Dumbbells'),
    ];
    for (final result in cases) {
      expect(result.suggestion, isNull);
      expect(result.baseline, isEmpty);
      expect(
        result.message,
        'Could not suggest a plan because some saved data is invalid.',
      );
    }
  });

  test('H4 tied scores use lower plan ID and three sets count once', () {
    final entries = [
      log(1, 'session', 1),
      log(1, 'session', 3),
      log(1, 'session', 2),
    ];
    final result = matchGear(
      plans: [plan(3), plan(2), plan(1)],
      entries: entries,
      equipment: 'Dumbbells',
    );
    expect(result.suggestion!.plan.id, 2);
    expect(result.ranked.map((score) => score.total), [3, 3, 2]);
    expect(finishedSessionCount(entries), 1);
    expect(result.lastWorkoutId, 1);
  });

  test(
    'latest set selects its session; tied times use session key ascending',
    () {
      final plans = [plan(1), plan(2), plan(3)];
      final entries = [
        log(1, 'a', 1),
        log(2, 'b', 3),
        log(1, 'a', 4),
        log(3, 'unfinished', 20, finished: false),
      ];
      expect(
        matchGear(
          plans: plans,
          entries: entries,
          equipment: 'Dumbbells',
        ).lastWorkoutId,
        1,
      );
      for (final tied in [
        [log(2, 'b', 4), log(1, 'a', 4)],
        [log(1, 'a', 4), log(2, 'b', 4)],
      ]) {
        expect(
          matchGear(
            plans: plans,
            entries: tied,
            equipment: 'Dumbbells',
          ).lastWorkoutId,
          1,
        );
      }
      expect(plans.map((plan) => plan.id), [1, 2, 3]);
      expect(entries.first.loggedAt.minute, 1);
    },
  );

  test('H5 counterexample: user wants plan 2 again, baseline matches', () {
    const expectedChoice = 2;
    final result = matchGear(
      plans: [plan(2), plan(3)],
      entries: [log(2, 'last', 1)],
      equipment: 'Dumbbells',
    );
    expect(result.suggestion!.plan.id, 3);
    expect(result.suggestion!.plan.id, isNot(expectedChoice));
    expect(result.baseline.first.plan.id, expectedChoice);
  });
}
