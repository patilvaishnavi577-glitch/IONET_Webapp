import 'package:flutter_test/flutter_test.dart';
import 'package:ionet_onboarding/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const IonetOnboardingApp());
    expect(find.byType(IonetOnboardingApp), findsOneWidget);
  });
}
