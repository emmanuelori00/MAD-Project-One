import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/data/training_log_store.dart';
import 'package:movement_quest/screens/history_screen.dart';
import 'package:movement_quest/screens/workout_screen.dart';

import 'support/fake_stores.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> openWorkout(WidgetTester tester, FakeLogStore store) async {
  await tester.pumpWidget(
    MaterialApp(
      home: WorkoutScreen(
        planName: 'Test plan',
        equipment: 'No equipment',
        workoutId: 1,
        logStore: store,
      ),
    ),
  );
  await tapText(tester, 'Start workout');
}

Future<void> fillSet(WidgetTester tester, {String reps = '10'}) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'Squats');
  await tester.enterText(find.byType(TextFormField).at(1), reps);
}

Future<void> openHistory(WidgetTester tester, FakeLogStore store) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HistoryScreen(
          store: store,
          plans: const [WorkoutReference(id: 1, title: 'Test plan')],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

TrainingEntry entry(String session, {bool finished = true}) => TrainingEntry(
  workoutId: 1,
  sessionKey: session,
  exerciseLabel: 'Squats',
  reps: 10,
  loggedAt: DateTime.utc(2026, 10, 26, 14),
  sessionFinished: finished,
);

void main() {
  testWidgets('Back asks before leaving and keeps saved unfinished sets', (
    tester,
  ) async {
    final store = FakeLogStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WorkoutScreen(
                    planName: 'Test plan',
                    equipment: 'Other',
                    workoutId: 1,
                    logStore: store,
                  ),
                ),
              ),
              child: const Text('Open workout'),
            ),
          ),
        ),
      ),
    );
    await tapText(tester, 'Open workout');
    await tapText(tester, 'Start workout');
    await fillSet(tester);
    await tapText(tester, 'Save set');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Leave workout?'), findsOneWidget);
    await tapText(tester, 'Cancel');
    expect(find.text('Current workout'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapText(tester, 'Leave workout');
    expect(find.text('Open workout'), findsOneWidget);
    expect(store.entries, hasLength(1));
    expect(store.entries.single.sessionFinished, false);
  });

  testWidgets('workout and history controls fit large text in landscape', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = FakeLogStore();
    Widget shell(Widget child) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: child,
      ),
    );
    await tester.pumpWidget(
      shell(
        WorkoutScreen(
          planName: 'A longer workout plan title',
          equipment: 'Resistance band',
          workoutId: 1,
          logStore: store,
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Start workout'), 150);
    await tapText(tester, 'Start workout');
    await tester.scrollUntilVisible(
      find.text('Save set'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    await store.add(entry('session-a'));
    await tester.pumpWidget(
      shell(
        Scaffold(
          body: HistoryScreen(
            store: store,
            plans: const [
              WorkoutReference(id: 1, title: 'A longer workout plan title'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Delete'), 150);
    await tapText(tester, 'Delete');
    expect(find.text('Delete this set?'), findsOneWidget);
    await tapText(tester, 'Cancel');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'three sets finish once and reset keeps saved unfinished history',
    (tester) async {
      final store = FakeLogStore();
      await openWorkout(tester, store);
      for (var i = 0; i < 3; i++) {
        await fillSet(tester);
        await tapText(tester, 'Save set');
      }
      expect(store.entries, hasLength(3));
      expect(store.entries.map((row) => row.sessionKey).toSet(), hasLength(1));
      expect(finishedSessionCount(store.entries), 0);
      await tapText(tester, 'Finish workout');
      expect(store.finishes, 1);
      expect(store.entries, hasLength(3));
      expect(finishedSessionCount(store.entries), 1);
      await tapText(tester, 'Start another workout');
      await fillSet(tester);
      await tapText(tester, 'Save set');
      await tapText(tester, 'Reset');
      await tapText(tester, 'Cancel');
      expect(find.text('Save set'), findsOneWidget);
      await tapText(tester, 'Reset');
      await tapText(tester, 'Reset workout');
      expect(store.entries, hasLength(4));
      expect(store.entries.last.sessionFinished, false);
      expect(finishedSessionCount(store.entries), 1);
      expect(find.text('Start workout'), findsOneWidget);
    },
  );

  testWidgets(
    'validation and failed writes keep draft; finish does not discard draft',
    (tester) async {
      final store = FakeLogStore();
      await openWorkout(tester, store);
      await fillSet(tester, reps: '-2');
      await tapText(tester, 'Save set');
      expect(
        find.text('Enter a whole number greater than zero.'),
        findsOneWidget,
      );
      expect(store.adds, 0);
      await fillSet(tester);
      store.failWrite = true;
      await tapText(tester, 'Save set');
      expect(find.textContaining('Could not save this set.'), findsOneWidget);
      expect(find.text('Squats'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      store.failWrite = false;
      await tapText(tester, 'Save set');
      await fillSet(tester, reps: '12');
      await tapText(tester, 'Finish workout');
      expect(store.finishes, 0);
      expect(find.textContaining('Save this set or clear'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), '');
      await tester.enterText(find.byType(TextFormField).at(1), '');
      store.failWrite = true;
      await tapText(tester, 'Finish workout');
      expect(find.textContaining('Could not finish'), findsOneWidget);
      expect(store.entries.single.sessionFinished, false);
      store.failWrite = false;
      await tapText(tester, 'Finish workout');
      expect(store.entries.single.sessionFinished, true);
    },
  );

  testWidgets('pending save ignores repeat taps and disposed callback', (
    tester,
  ) async {
    final store = FakeLogStore()..pending = Completer<void>();
    await openWorkout(tester, store);
    await fillSet(tester);
    await tester.ensureVisible(find.text('Save set'));
    await tester.tap(find.text('Save set'));
    await tester.tap(find.text('Save set'));
    await tester.pump();
    expect(store.adds, 1);
    await tester.pumpWidget(const SizedBox());
    store.pending!.complete();
    await tester.pumpAndSettle();
    expect(store.entries, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending finish only updates the session once', (tester) async {
    final store = FakeLogStore();
    await openWorkout(tester, store);
    await fillSet(tester);
    await tapText(tester, 'Save set');
    store.pending = Completer<void>();
    await tester.ensureVisible(find.text('Finish workout'));
    await tester.tap(find.text('Finish workout'));
    await tester.tap(find.text('Finish workout'));
    await tester.pump();
    expect(store.finishes, 1);
    store.pending!.complete();
    await tester.pumpAndSettle();
    expect(finishedSessionCount(store.entries), 1);
  });

  testWidgets(
    'history edit preserves session and canceled deletion keeps data',
    (tester) async {
      final store = FakeLogStore();
      await store.add(entry('session-a'));
      await store.add(entry('session-a'));
      await store.add(entry('session-a'));
      await openHistory(tester, store);
      expect(find.text('Finished workouts: 1'), findsOneWidget);
      await tester.tap(find.text('Edit').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, '15');
      store.failWrite = true;
      await tapText(tester, 'Save entry');
      expect(find.text('15'), findsOneWidget);
      expect(find.textContaining('Could not save this entry'), findsOneWidget);
      store.failWrite = false;
      await tapText(tester, 'Save entry');
      expect(store.entries.first.reps, 15);
      expect(store.entries.first.sessionKey, 'session-a');
      await tester.tap(find.text('Delete').first);
      await tester.pumpAndSettle();
      await tapText(tester, 'Cancel');
      expect(store.deletes, 0);
      for (var remaining = 2; remaining >= 0; remaining--) {
        await tester.tap(find.text('Delete').first);
        await tester.pumpAndSettle();
        await tapText(tester, 'Delete set');
        expect(store.entries, hasLength(remaining));
        expect(
          find.text('Finished workouts: ${remaining == 0 ? 0 : 1}'),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets(
    'manual entry adds a finished workout and may reuse its session',
    (tester) async {
      final store = FakeLogStore();
      await openHistory(tester, store);
      await tapText(tester, 'Add entry');
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tapText(tester, 'Test plan');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Exercise name'),
        'Rows',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Repetitions'),
        '8',
      );
      await tapText(tester, 'Save entry');
      expect(store.entries, hasLength(1));
      expect(find.text('Finished workouts: 1'), findsOneWidget);
      final key = store.entries.single.sessionKey;
      await tapText(tester, 'Add entry');
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tapText(tester, 'Test plan');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(' · Finished').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Exercise name'),
        'Rows',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Repetitions'),
        '9',
      );
      await tapText(tester, 'Save entry');
      expect(store.entries, hasLength(2));
      expect(store.entries.last.sessionKey, key);
      expect(find.text('Finished workouts: 1'), findsOneWidget);
    },
  );

  testWidgets('history retries load and deletion errors without losing rows', (
    tester,
  ) async {
    final store = FakeLogStore();
    await store.add(entry('session-a'));
    store.failRead = true;
    await openHistory(tester, store);
    expect(find.text('Could not load history. Try again.'), findsOneWidget);
    expect(find.text('No workout history yet.'), findsNothing);
    store.failRead = false;
    await tapText(tester, 'Refresh');
    store.failWrite = true;
    await tapText(tester, 'Delete');
    await tapText(tester, 'Delete set');
    expect(store.entries, hasLength(1));
    expect(find.text('Could not delete this set. Try again.'), findsOneWidget);
  });

  testWidgets('unconnected screens cannot pretend to save data', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WorkoutScreen(planName: 'Example', equipment: 'Other'),
      ),
    );
    final start = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start workout'),
    );
    expect(start.onPressed, isNull);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HistoryScreen())),
    );
    expect(find.textContaining('History is not available yet'), findsOneWidget);
    expect(find.text('No workout history yet.'), findsNothing);
  });
}
