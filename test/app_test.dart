import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/app.dart';

void main() {
  testWidgets('app starts and displays the Movement Quest home screen', (
    tester,
  ) async {
    await tester.pumpWidget(const MovementQuestApp());

    expect(find.text('Movement Quest'), findsOneWidget);
    expect(find.text('Welcome to Movement Quest'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
