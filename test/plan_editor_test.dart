import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/data/app_settings.dart';
import 'package:movement_quest/data/workout_plan.dart';
import 'package:movement_quest/screens/plan_editor_screen.dart';

import 'support/fake_stores.dart';

Future<void> showField(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      150,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(finder.last);
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await showField(tester, find.text(text));
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await showField(tester, field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> openEditor(
  WidgetTester tester,
  FakePlanStore store, {
  AppSettings defaults = const AppSettings(),
  WorkoutPlan? plan,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<WorkoutPlan>(
              MaterialPageRoute(
                builder: (_) => PlanEditorScreen(
                  store: store,
                  defaults: defaults,
                  plan: plan,
                ),
              ),
            ),
            child: const Text('Open editor'),
          ),
        ),
      ),
    ),
  );
  await tapText(tester, 'Open editor');
}

void main() {
  testWidgets(
    'invalid plan fields stay open and no preference requires equipment',
    (tester) async {
      final store = FakePlanStore();
      await openEditor(tester, store);
      await tapText(tester, 'Save plan');
      expect(
        find.text('Enter a plan name with 1–60 characters.'),
        findsOneWidget,
      );
      expect(find.text('Choose equipment for this plan.'), findsOneWidget);
      expect(store.adds, 0);
      await fill(tester, 'Plan name', 'a' * 61);
      await fill(tester, 'Notes (optional)', 'a' * 501);
      await tapText(tester, 'Save plan');
      expect(
        find.text('Keep the notes to 500 characters or less.'),
        findsOneWidget,
      );
      expect(store.adds, 0);
      await fill(tester, 'Plan name', '  Valid plan  ');
      await fill(tester, 'Notes (optional)', 'Short note');
      await showField(tester, find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tapText(tester, 'Resistance band');
      await tapText(tester, 'Save plan');
      expect(store.plans.single.title, 'Valid plan');
      expect(store.plans.single.equipmentTag, 'Resistance band');
      expect(find.text('Open editor'), findsOneWidget);
    },
  );

  testWidgets('failed saves retain the form and retry saves once', (
    tester,
  ) async {
    final store = FakePlanStore()..failWrite = true;
    await openEditor(
      tester,
      store,
      defaults: const AppSettings(equipment: 'Dumbbells', defaultEffort: 4),
    );
    await fill(tester, 'Plan name', 'Keep this name');
    await fill(tester, 'Notes (optional)', 'Keep these notes');
    await tapText(tester, 'Save plan');
    expect(
      find.text(
        'Could not save this plan. Your changes are still here. Try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Keep this name'), findsOneWidget);
    expect(find.text('Keep these notes'), findsOneWidget);
    expect(store.plans, isEmpty);
    store.failWrite = false;
    await tapText(tester, 'Save plan');
    expect(store.plans, hasLength(1));
    expect(store.plans.single.effortPreference, 4);
    expect(find.text('Open editor'), findsOneWidget);
  });

  testWidgets('Cancel and Back both protect an unsaved draft', (tester) async {
    final store = FakePlanStore();
    await openEditor(tester, store);
    await fill(tester, 'Plan name', 'Unsaved plan');
    await tapText(tester, 'Cancel');
    expect(find.text('Discard changes?'), findsOneWidget);
    await tapText(tester, 'Cancel');
    expect(find.text('Unsaved plan'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tapText(tester, 'Discard');
    expect(find.text('Open editor'), findsOneWidget);
    expect(store.adds, 0);
  });

  testWidgets(
    'pending saves block repeated taps and ignore disposed callbacks',
    (tester) async {
      final store = FakePlanStore()..pending = Completer<void>();
      await openEditor(
        tester,
        store,
        defaults: const AppSettings(equipment: 'No equipment'),
      );
      await fill(tester, 'Plan name', 'Save once');
      await showField(tester, find.text('Save plan'));
      await tester.tap(find.text('Save plan'));
      await tester.tap(find.text('Save plan'));
      await tester.pump();
      expect(store.adds, 1);
      await tester.pageBack();
      await tester.pump();
      expect(find.text('Discard changes?'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      store.pending!.complete();
      await tester.pumpAndSettle();
      expect(store.plans, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing uses the saved plan and does not insert another record',
    (tester) async {
      final store = FakePlanStore();
      await store.addPlan(
        const WorkoutPlan(
          title: 'Original',
          equipmentTag: 'Other',
          planNote: 'Saved note',
          effortPreference: 2,
        ),
      );
      final original = store.plans.single;
      await openEditor(
        tester,
        store,
        plan: original,
        defaults: const AppSettings(equipment: 'Dumbbells', defaultEffort: 5),
      );
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('Effort: 2 of 5'), findsOneWidget);
      await fill(tester, 'Plan name', 'Changed');
      await tapText(tester, 'Save plan');
      expect(store.plans.single.id, original.id);
      expect(store.plans.single.title, 'Changed');
      expect(store.adds, 1);
      expect(store.updates, 1);
    },
  );

  testWidgets('the plan form is usable with large text in landscape', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = FakePlanStore();
    await openEditor(
      tester,
      store,
      defaults: const AppSettings(equipment: 'Resistance band'),
      textScale: 2,
    );
    await fill(tester, 'Plan name', 'Landscape plan');
    await fill(tester, 'Notes (optional)', 'Readable notes');
    await showField(tester, find.byType(Slider));
    await tester.tap(find.byType(Slider));
    await tester.pumpAndSettle();
    await tapText(tester, 'Save plan');
    expect(store.plans.single.title, 'Landscape plan');
    expect(tester.takeException(), isNull);
  });
}
