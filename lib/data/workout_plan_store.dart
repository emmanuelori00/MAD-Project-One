import 'workout_plan.dart';

abstract class WorkoutPlanStore {
  Future<List<WorkoutPlan>> readPlans();
  Future<int> addPlan(WorkoutPlan plan);
  Future<void> updatePlan(WorkoutPlan plan);
  Future<void> deletePlan(int id);
}

class PlanHasLogsException implements Exception {
  const PlanHasLogsException();

  @override
  String toString() =>
      'Remove this plan’s saved sets before deleting the plan.';
}
