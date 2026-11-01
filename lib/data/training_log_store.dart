import 'dart:math';

class WorkoutReference {
  const WorkoutReference({required this.id, required this.title});

  final int id;
  final String title;
}

class TrainingEntry {
  const TrainingEntry({
    this.id,
    required this.workoutId,
    required this.sessionKey,
    required this.exerciseLabel,
    required this.reps,
    required this.loggedAt,
    required this.sessionFinished,
  });

  final int? id;
  final int workoutId;
  final String sessionKey;
  final String exerciseLabel;
  final int reps;
  final DateTime loggedAt;
  final bool sessionFinished;
}

// MQ09 supplies the persistent adapter used by these screens.
abstract class TrainingLogStore {
  Future<List<TrainingEntry>> readAll();
  Future<void> add(TrainingEntry entry);

  // Corrections preserve the workout, session, timestamp and finish flag.
  Future<void> correct(
    int id, {
    required String exerciseLabel,
    required int reps,
  });
  Future<void> delete(int id);

  // Atomically finish existing rows without inserting a set. Repeated calls
  // for the same session must be harmless.
  Future<void> finishSession(String sessionKey);
}

String newSessionKey() {
  final random = Random.secure();
  return '${DateTime.now().toUtc().microsecondsSinceEpoch}-'
      '${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
}

int finishedSessionCount(Iterable<TrainingEntry> entries) => entries
    .where((entry) => entry.sessionFinished)
    .map((entry) => entry.sessionKey)
    .toSet()
    .length;

String? validateExercise(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty || text.length > 60
      ? 'Enter an exercise name with 1–60 characters.'
      : null;
}

String? validateReps(String? value) {
  final text = value?.trim() ?? '';
  final reps = int.tryParse(text);
  return !RegExp(r'^[0-9]+$').hasMatch(text) || reps == null || reps <= 0
      ? 'Enter a whole number greater than zero.'
      : null;
}
