import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/app.dart';
import 'package:movement_quest/data/app_settings.dart';
import 'package:movement_quest/data/training_log_store.dart';
import 'package:movement_quest/data/workout_plan.dart';
import 'package:movement_quest/screens/plans_screen.dart';

import 'app_test.dart' show tapText, fill;
import 'support/fake_stores.dart';

final suggestionCard = find.byKey(const ValueKey('gear-match'));

void main() {
  testWidgets(
    'view opens real plan without starting; dismissal survives tab return',
    (tester) async {
      final logs = FakeLogStore();
      final plans = FakePlanStore(logs: logs);
      final settings = FakeSettingsStore()
        ..value = const AppSettings(equipment: 'Dumbbells');
      for (final name in ['Plan A', 'Plan B']) {
        await plans.addPlan(
          WorkoutPlan(
            title: name,
            equipmentTag: 'Dumbbells',
            planNote: '',
            effortPreference: 4,
          ),
        );
      }
      await logs.add(
        TrainingEntry(
          workoutId: 1,
          sessionKey: 'last',
          exerciseLabel: 'Rows',
          reps: 8,
          loggedAt: DateTime.utc(2026, 10, 31),
          sessionFinished: true,
        ),
      );
      await tester.pumpWidget(
        MovementQuestApp(
          settingsStore: settings,
          planStore: plans,
          logStore: logs,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: suggestionCard, matching: find.text('Plan B')),
        findsOneWidget,
      );
      expect(find.text('Equipment match: +2'), findsOneWidget);
      expect(
        find.text('Different from your last finished workout: +1'),
        findsOneWidget,
      );
      await tapText(tester, 'View plan');
      expect(find.text('Current workout'), findsOneWidget);
      expect(find.text('Plan B'), findsOneWidget);
      expect(find.text('Start workout'), findsOneWidget);
      expect(logs.entries, hasLength(1));
      expect(logs.finishes, 0);
      expect(settings.value.defaultEffort, 3);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapText(tester, 'Not now');
      expect(suggestionCard, findsNothing);
      await tapText(tester, 'History');
      await tapText(tester, 'Plans');
      expect(suggestionCard, findsNothing);
      await tapText(tester, 'Settings');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tapText(tester, 'No preference');
      await tapText(tester, 'Save settings');
      await tapText(tester, 'Plans');
      expect(suggestionCard, findsOneWidget);
      expect(
        find.text('Equipment match: skipped (no preference)'),
        findsOneWidget,
      );
      await tapText(tester, 'View plan');
      await tapText(tester, 'Start workout');
      await fill(tester, 'Exercise name', 'Rows');
      await fill(tester, 'Repetitions', '6');
      await tapText(tester, 'Save set');
      await tapText(tester, 'Finish workout');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: suggestionCard, matching: find.text('Plan A')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty and invalid data show feedback without a suggestion', (
    tester,
  ) async {
    Future<void> show(List<WorkoutPlan> plans, String equipment) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlansScreen(
              plans: plans,
              entries: const [],
              preferredEquipment: equipment,
              loaded: true,
              busy: false,
              finishedWorkouts: 0,
              settingsReady: true,
              onRetry: () {},
              onAddPlan: () {},
              onOpenPlan: (_) {},
              onEditPlan: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show([], 'No preference');
    expect(find.text('Add a plan first to get a suggestion.'), findsOneWidget);
    expect(find.text('View plan'), findsNothing);
    await show([], 'bad value');
    expect(
      find.text('Could not suggest a plan because some saved data is invalid.'),
      findsOneWidget,
    );
    expect(find.text('View plan'), findsNothing);
  });

  testWidgets('suggestion buttons fit large text in landscape', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: PlansScreen(
              plans: const [
                WorkoutPlan(
                  id: 1,
                  title: 'My saved workout',
                  equipmentTag: 'Dumbbells',
                  planNote: '',
                  effortPreference: 3,
                ),
              ],
              entries: const [],
              preferredEquipment: 'Dumbbells',
              loaded: true,
              busy: false,
              finishedWorkouts: 0,
              settingsReady: true,
              onRetry: () {},
              onAddPlan: () {},
              onOpenPlan: (_) => opened = true,
              onEditPlan: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapText(tester, 'View plan');
    expect(opened, isTrue);
    await tapText(tester, 'Not now');
    expect(suggestionCard, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
