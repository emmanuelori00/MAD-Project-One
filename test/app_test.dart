import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/app.dart';
import 'package:movement_quest/data/app_settings.dart';
import 'package:movement_quest/data/training_log_store.dart';
import 'package:movement_quest/data/workout_plan.dart';
import 'package:movement_quest/screens/plans_screen.dart';
import 'package:movement_quest/widgets/plan_card.dart';

import 'support/fake_stores.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  if (find.text(text).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(text),
      150,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> checkFinishedCount(WidgetTester tester, int count) async {
  final total = find.text('Finished workouts: $count');
  await tester.scrollUntilVisible(
    total,
    -150,
    scrollable: find.descendant(
      of: find.byType(PlansScreen),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
  expect(total, findsOneWidget);
}

WorkoutPlan plan(String title, {String equipment = 'No equipment'}) =>
    WorkoutPlan(
      title: title,
      equipmentTag: equipment,
      planNote: '',
      effortPreference: 3,
    );

Future<void> openApp(
  WidgetTester tester,
  FakePlanStore plans,
  FakeLogStore logs, {
  FakeSettingsStore? settings,
}) async {
  await tester.pumpWidget(
    MovementQuestApp(
      settingsStore: settings ?? FakeSettingsStore(),
      planStore: plans,
      logStore: logs,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('five saved-data screens and return paths work at $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final logs = FakeLogStore();
      final plans = FakePlanStore(logs: logs);
      await plans.addPlan(plan('Plan A'));
      await plans.addPlan(plan('Plan B', equipment: 'Dumbbells'));
      await openApp(tester, plans, logs);
      expect(find.text('Workout plans'), findsOneWidget);
      await tapText(tester, 'Add plan');
      expect(find.text('Plan name'), findsOneWidget);
      await tapText(tester, 'Cancel');
      expect(find.text('Workout plans'), findsOneWidget);

      final firstCard = find.byWidgetPredicate(
        (widget) => widget is PlanCard && widget.name == 'Plan A',
      );
      await tester.scrollUntilVisible(
        firstCard,
        150,
        scrollable: find.descendant(
          of: find.byType(PlansScreen),
          matching: find.byType(Scrollable),
        ),
      );
      final openFirst = find.descendant(
        of: firstCard,
        matching: find.text('Open'),
      );
      await tester.ensureVisible(openFirst);
      await tester.pumpAndSettle();
      await tester.tap(openFirst);
      await tester.pumpAndSettle();
      expect(find.text('Current workout'), findsOneWidget);
      expect(find.text('Plan A'), findsOneWidget);
      await tapText(tester, 'Edit plan');
      expect(find.text('Edit plan'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Current workout'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      final secondCard = find.byWidgetPredicate(
        (widget) => widget is PlanCard && widget.name == 'Plan B',
      );
      await tester.scrollUntilVisible(
        secondCard,
        150,
        scrollable: find.descendant(
          of: find.byType(PlansScreen),
          matching: find.byType(Scrollable),
        ),
      );
      final editSecond = find.descendant(
        of: secondCard,
        matching: find.text('Edit'),
      );
      await tester.ensureVisible(editSecond);
      await tester.pumpAndSettle();
      await tester.tap(editSecond);
      await tester.pumpAndSettle();
      expect(find.text('Plan B'), findsOneWidget);
      await tapText(tester, 'Cancel');
      await tapText(tester, 'History');
      expect(find.text('Workout history'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Workout plans'), findsOneWidget);
      await tapText(tester, 'Settings');
      expect(find.text('Equipment preference'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Workout plans'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'create a plan, finish sets, correct history, and cancel deletion',
    (tester) async {
      final logs = FakeLogStore();
      final plans = FakePlanStore(logs: logs);
      final settings = FakeSettingsStore()
        ..value = const AppSettings(equipment: 'Dumbbells', defaultEffort: 4);
      await openApp(tester, plans, logs, settings: settings);
      expect(
        find.text('No plans yet. Add a plan to get started.'),
        findsOneWidget,
      );
      await tapText(tester, 'Add plan');
      await fill(tester, 'Plan name', 'My workout');
      await fill(tester, 'Notes (optional)', 'Two sets today');
      expect(find.text('Effort: 4 of 5'), findsOneWidget);
      await tapText(tester, 'Save plan');
      expect(plans.plans.single.title, 'My workout');
      expect(plans.plans.single.equipmentTag, 'Dumbbells');
      await tapText(tester, 'Open');
      expect(find.text('Two sets today'), findsOneWidget);
      await tapText(tester, 'Start workout');
      for (var i = 0; i < 2; i++) {
        await fill(tester, 'Exercise name', 'Rows');
        await fill(tester, 'Repetitions', '8');
        await tapText(tester, 'Save set');
      }
      await tapText(tester, 'Finish workout');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await checkFinishedCount(tester, 1);
      await tapText(tester, 'History');
      expect(find.text('My workout'), findsOneWidget);
      expect(find.text('Rows · 8 reps'), findsNWidgets(2));
      await tester.tap(find.text('Edit').first);
      await tester.pumpAndSettle();
      await fill(tester, 'Repetitions', '12');
      await tapText(tester, 'Save entry');
      expect(find.text('Rows · 12 reps'), findsOneWidget);
      await tester.tap(find.text('Delete').first);
      await tester.pumpAndSettle();
      await tapText(tester, 'Cancel');
      expect(logs.deletes, 0);
      expect(logs.entries, hasLength(2));
      for (var remaining = 1; remaining >= 0; remaining--) {
        await tester.tap(find.text('Delete').first);
        await tester.pumpAndSettle();
        await tapText(tester, 'Delete set');
        expect(logs.entries, hasLength(remaining));
      }
      await tapText(tester, 'Plans');
      await checkFinishedCount(tester, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'plan editing refreshes details and history keeps the new title',
    (tester) async {
      final logs = FakeLogStore();
      final plans = FakePlanStore(logs: logs);
      final id = await plans.addPlan(plan('Original'));
      await logs.add(
        TrainingEntry(
          workoutId: id,
          sessionKey: 'saved',
          exerciseLabel: 'Rows',
          reps: 8,
          loggedAt: DateTime.utc(2026, 10, 31),
          sessionFinished: true,
        ),
      );
      await openApp(tester, plans, logs);
      await tapText(tester, 'Open');
      await tapText(tester, 'Edit plan');
      await fill(tester, 'Plan name', 'Renamed');
      await fill(tester, 'Notes (optional)', 'New notes');
      await tapText(tester, 'Save plan');
      expect(find.text('Renamed'), findsOneWidget);
      expect(find.text('New notes'), findsOneWidget);
      await tapText(tester, 'Edit plan');
      expect(find.text('Renamed'), findsOneWidget);
      await tapText(tester, 'Cancel');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapText(tester, 'History');
      expect(find.text('Renamed'), findsOneWidget);
      expect(find.text('Original'), findsNothing);
    },
  );

  testWidgets(
    'plan deletion can be canceled, blocks logs, and refreshes after success',
    (tester) async {
      final logs = FakeLogStore();
      final plans = FakePlanStore(logs: logs);
      final id = await plans.addPlan(plan('Protected plan'));
      await logs.add(
        TrainingEntry(
          workoutId: id,
          sessionKey: 'saved',
          exerciseLabel: 'Rows',
          reps: 8,
          loggedAt: DateTime.utc(2026, 10, 31),
          sessionFinished: false,
        ),
      );
      await openApp(tester, plans, logs);
      await tapText(tester, 'Open');
      await tapText(tester, 'Delete plan');
      await tapText(tester, 'Cancel');
      expect(plans.deletes, 0);
      await tapText(tester, 'Delete plan');
      await tapText(tester, 'Delete plan');
      expect(
        find.text('Remove this plan’s saved sets before deleting the plan.'),
        findsOneWidget,
      );
      expect(plans.plans, hasLength(1));
      expect(logs.entries, hasLength(1));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapText(tester, 'History');
      await tapText(tester, 'Delete');
      await tapText(tester, 'Delete set');
      await tapText(tester, 'Plans');
      await tapText(tester, 'Open');
      await tapText(tester, 'Delete plan');
      await tapText(tester, 'Delete plan');
      expect(
        find.text('No plans yet. Add a plan to get started.'),
        findsOneWidget,
      );
      expect(plans.plans, isEmpty);
    },
  );

  testWidgets('plan load failures retry and equipment filters can be cleared', (
    tester,
  ) async {
    final logs = FakeLogStore();
    final plans = FakePlanStore(logs: logs);
    await plans.addPlan(plan('Bodyweight'));
    plans.failRead = true;
    await openApp(tester, plans, logs);
    expect(
      find.text('Could not load your workouts. Try again.'),
      findsOneWidget,
    );
    expect(find.text('No plans yet. Add a plan to get started.'), findsNothing);
    plans.failRead = false;
    await tapText(tester, 'Retry');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tapText(tester, 'Dumbbells');
    expect(find.text('No plans match this equipment.'), findsOneWidget);
    await tapText(tester, 'Clear filter');
    expect(
      find.descendant(
        of: find.byType(PlanCard),
        matching: find.text('Bodyweight'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'new plans use saved defaults while existing plans keep their values',
    (tester) async {
      final logs = FakeLogStore();
      final plans = FakePlanStore(logs: logs);
      await plans.addPlan(plan('Existing'));
      await openApp(tester, plans, logs);
      await tapText(tester, 'Settings');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tapText(tester, 'Dumbbells');
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(5);
      await tester.pumpAndSettle();
      await tapText(tester, 'Save settings');
      await tapText(tester, 'Plans');
      await tapText(tester, 'Add plan');
      expect(find.text('Dumbbells'), findsOneWidget);
      expect(find.text('Effort: 5 of 5'), findsOneWidget);
      await tapText(tester, 'Cancel');
      await tapText(tester, 'Edit');
      expect(find.text('No equipment'), findsOneWidget);
      expect(find.text('Effort: 3 of 5'), findsOneWidget);
    },
  );

  testWidgets('cards remain usable with large text in landscape', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: ListView(
              children: [
                PlanCard(
                  name: 'A longer workout plan name',
                  equipment: 'Resistance band',
                  onOpen: () {},
                  onEdit: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('A longer workout plan name'), findsOneWidget);
    await tester.ensureVisible(find.text('Edit'));
    expect(tester.takeException(), isNull);
  });
}
