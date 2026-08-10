import 'package:flutter_test/flutter_test.dart';
import 'package:ionet_onboarding/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    
    await tester.pumpWidget(IonetOnboardingApp(prefs: prefs));
    expect(find.byType(IonetOnboardingApp), findsOneWidget);
  });
}
