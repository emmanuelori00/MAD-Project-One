import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/app.dart';
import 'package:movement_quest/screens/plans_screen.dart';
import 'package:movement_quest/widgets/plan_card.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('five roles and return paths work at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const MovementQuestApp());

      expect(find.text('Workout plans'), findsOneWidget);
      expect(find.byType(PlanCard), findsWidgets);
      await tester.tap(find.text('Add plan'));
      await tester.pumpAndSettle();
      expect(find.text('Plan editing is not available yet.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Workout plans'), findsOneWidget);

      await tester.ensureVisible(find.text('Open').first);
      await tester.tap(find.text('Open').first);
      await tester.pumpAndSettle();
      expect(find.text('Current workout'), findsOneWidget);
      expect(find.text('Plan A'), findsOneWidget);
      await tester.tap(find.text('Edit plan'));
      await tester.pumpAndSettle();
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
      await tester.pumpAndSettle();
      final editSecond = find.descendant(
        of: secondCard,
        matching: find.text('Edit'),
      );
      await tester.ensureVisible(editSecond);
      await tester.tap(editSecond);
      await tester.pumpAndSettle();
      expect(find.text('Plan B'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Workout history'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Workout plans'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Settings are not available yet.'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Workout plans'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

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
