import 'app_settings.dart';
import 'training_log_store.dart';
import 'workout_plan.dart';

class PlanScore {
  const PlanScore(this.plan, this.equipmentPoints, this.recentPoints);

  final WorkoutPlan plan;
  final int equipmentPoints;
  final int recentPoints;
  int get total => equipmentPoints + recentPoints;
}

class GearMatchResult {
  const GearMatchResult({
    this.ranked = const [],
    this.baseline = const [],
    this.lastWorkoutId,
    this.message,
  });

  final List<PlanScore> ranked;
  final List<PlanScore> baseline;
  final int? lastWorkoutId;
  final String? message;
  PlanScore? get suggestion => ranked.isEmpty ? null : ranked.first;
}

GearMatchResult matchGear({
  required List<WorkoutPlan> plans,
  required List<TrainingEntry> entries,
  required String equipment,
}) {
  const invalid = GearMatchResult(
    message: 'Could not suggest a plan because some saved data is invalid.',
  );
  if (!equipmentChoices.contains(equipment)) return invalid;
  final ids = <int>{};
  for (final plan in plans) {
    if (!plan.isValid || plan.id == null || !ids.add(plan.id!)) {
      return invalid;
    }
  }

  final sessions = <String, TrainingEntry>{};
  for (final entry in entries) {
    if (!ids.contains(entry.workoutId) ||
        entry.sessionKey.trim().isEmpty ||
        validateExercise(entry.exerciseLabel) != null ||
        entry.reps <= 0) {
      return invalid;
    }
    final previous = sessions[entry.sessionKey];
    if (previous != null &&
        (previous.workoutId != entry.workoutId ||
            previous.sessionFinished != entry.sessionFinished)) {
      return invalid;
    }
    if (previous == null || entry.loggedAt.isAfter(previous.loggedAt)) {
      sessions[entry.sessionKey] = entry;
    }
  }
  if (plans.isEmpty) {
    return const GearMatchResult(
      message: 'Add a plan first to get a suggestion.',
    );
  }

  final finished =
      sessions.values.where((entry) => entry.sessionFinished).toList()
        ..sort((a, b) {
          final timeOrder = b.loggedAt.compareTo(a.loggedAt);
          return timeOrder != 0
              ? timeOrder
              : a.sessionKey.compareTo(b.sessionKey);
        });
  final lastId = finished.isEmpty ? null : finished.first.workoutId;
  final ranked = <PlanScore>[];
  final baseline = <PlanScore>[];
  for (final plan in plans) {
    final equipmentPoints =
        equipment != 'No preference' && plan.equipmentTag == equipment ? 2 : 0;
    final recentPoints = lastId != null && plan.id != lastId ? 1 : 0;
    ranked.add(PlanScore(plan, equipmentPoints, recentPoints));
    baseline.add(PlanScore(plan, equipmentPoints, 0));
  }
  int compare(PlanScore a, PlanScore b) {
    final scoreOrder = b.total.compareTo(a.total);
    return scoreOrder != 0 ? scoreOrder : a.plan.id!.compareTo(b.plan.id!);
  }

  ranked.sort(compare);
  baseline.sort(compare);
  return GearMatchResult(
    ranked: List.unmodifiable(ranked),
    baseline: List.unmodifiable(baseline),
    lastWorkoutId: lastId,
  );
}
