import 'app_settings.dart';

class WorkoutPlan {
  const WorkoutPlan({
    this.id,
    required this.title,
    required this.equipmentTag,
    required this.planNote,
    required this.effortPreference,
  });

  final int? id;
  final String title;
  final String equipmentTag;
  final String planNote;
  final int effortPreference;

  bool get isValid =>
      (id == null || id! > 0) &&
      validatePlanTitle(title) == null &&
      equipmentChoices.skip(1).contains(equipmentTag) &&
      validatePlanNote(planNote) == null &&
      effortPreference >= 1 &&
      effortPreference <= 5;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'title': title.trim(),
    'equipmentTag': equipmentTag,
    'planNote': planNote,
    'effortPreference': effortPreference,
  };

  factory WorkoutPlan.fromMap(Map<String, Object?> map) {
    final plan = WorkoutPlan(
      id: map['id'] as int,
      title: map['title'] as String,
      equipmentTag: map['equipmentTag'] as String,
      planNote: map['planNote'] as String,
      effortPreference: map['effortPreference'] as int,
    );

    if (!plan.isValid) {
      throw const FormatException('Invalid workout plan');
    }

    return plan;
  }
}

String? validatePlanTitle(String? value) {
  final title = value?.trim() ?? '';
  return title.isEmpty || title.length > 60
      ? 'Enter a plan name with 1–60 characters.'
      : null;
}

String? validatePlanNote(String? value) {
  return (value ?? '').length > 500
      ? 'Keep the notes to 500 characters or less.'
      : null;
}
