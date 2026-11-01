import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/app.dart';
import 'package:movement_quest/data/app_settings.dart';
import 'package:movement_quest/data/movement_quest_database.dart';
import 'package:movement_quest/widgets/plan_card.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_stores.dart';

Future<void> settleDatabase(WidgetTester tester) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final loading = find
        .byType(LinearProgressIndicator, skipOffstage: false)
        .evaluate()
        .isNotEmpty;
    final saving = find
        .text('Saving…', skipOffstage: false)
        .evaluate()
        .isNotEmpty;
    if (!loading && !saving && !tester.binding.hasScheduledFrame) return;
  }
  fail('The database operation or screen transition did not finish.');
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await settleDatabase(tester);
  await tester.tap(find.text(text).last);
  await settleDatabase(tester);
}

Future<void> fill(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await settleDatabase(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  testWidgets(
    'saved plans and finished sets return to the screens after reopening SQLite',
    (tester) async {
      late Directory folder;
      late MovementQuestDatabase database;
      await tester.runAsync(() async {
        final parent = await Directory('.dart_tool').create(recursive: true);
        folder = await parent.createTemp('movement_quest_app_test_');
        database = MovementQuestDatabase(
          factory: databaseFactoryFfiNoIsolate,
          databasePath: join(folder.path, 'app.db'),
        );
        await database.database;
      });
      addTearDown(() async {
        await database.close();
        await folder.delete(recursive: true);
      });
      final settings = FakeSettingsStore()
        ..value = const AppSettings(equipment: 'Dumbbells');
      Widget app() => MovementQuestApp(
        settingsStore: settings,
        planStore: database,
        logStore: database,
      );
      await tester.pumpWidget(app());
      await settleDatabase(tester);
      await tapText(tester, 'Add plan');
      await fill(tester, 'Plan name', 'Persistent plan');
      await tapText(tester, 'Save plan');
      await tapText(tester, 'Open');
      await tapText(tester, 'Start workout');
      await fill(tester, 'Exercise name', 'Rows');
      await fill(tester, 'Repetitions', '9');
      await tapText(tester, 'Save set');
      await tapText(tester, 'Finish workout');
      await tester.pageBack();
      await settleDatabase(tester);
      expect(find.text('Finished workouts: 1'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await database.close();
        database = MovementQuestDatabase(
          factory: databaseFactoryFfiNoIsolate,
          databasePath: join(folder.path, 'app.db'),
        );
        await database.database;
      });
      await tester.pumpWidget(app());
      await settleDatabase(tester);
      expect(
        find.descendant(
          of: find.byType(PlanCard),
          matching: find.text('Persistent plan'),
        ),
        findsOneWidget,
      );
      expect(find.text('Finished workouts: 1'), findsOneWidget);
      await tapText(tester, 'History');
      expect(find.text('Rows · 9 reps'), findsOneWidget);
      expect(find.text('Persistent plan'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
