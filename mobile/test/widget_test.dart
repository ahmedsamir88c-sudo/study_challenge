import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('App starts smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const StudyChallengeApp());
    expect(find.byType(StudyChallengeApp), findsOneWidget);
  });
}
