import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roomlyst/core/network/api_client.dart';
import 'package:roomlyst/features/auth/presentation/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Social Authentication Tests (Google & Apple ID)', () {
    testWidgets('LoginScreen renders Google and Apple ID sign-in buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Verify Social Login Buttons are visible
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.textContaining('100% Free authentication'), findsOneWidget);

      // Verify Standard login fields are present
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Continue as Guest / Explore Demo'), findsOneWidget);
    });

    testWidgets('Tapping Continue with Google triggers authentication and demo token', (tester) async {
      bool loginSuccessful = false;
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            isDemo: true,
            onLoginSuccess: () {
              loginSuccessful = true;
            },
          ),
        ),
      );

      // Tap Google Sign-in button
      final googleBtn = find.text('Continue with Google');
      expect(googleBtn, findsOneWidget);
      await tester.tap(googleBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Verify token was stored
      final token = await ApiClient.getToken();
      expect(token, isNotNull);
      expect(token, contains('jwt_token'));
      expect(loginSuccessful, isTrue);
    });
  });
}
