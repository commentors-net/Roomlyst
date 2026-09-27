import 'package:flutter_test/flutter_test.dart';
import 'package:roomlyst/main.dart';

void main() {
  testWidgets('Roomlyst app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RoomlystApp());

    // Verify brand title and tagline are present on the login screen
    expect(find.text('Roomlyst'), findsOneWidget);
    expect(find.text('AI-Powered Interior Design & Renovation'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Continue as Guest / Explore Demo'), findsOneWidget);
  });
}
