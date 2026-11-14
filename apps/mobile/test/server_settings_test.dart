import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roomlyst/core/config/app_config.dart';
import 'package:roomlyst/core/network/api_client.dart';
import 'package:roomlyst/features/settings/presentation/server_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppConfig.init();
  });

  group('Server Settings & Persistence Tests', () {
    testWidgets('ServerSettingsScreen renders server type choices and URL field', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ServerSettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Server & App Settings'), findsOneWidget);
      expect(find.text('Backend Endpoint Selection'), findsOneWidget);
      expect(find.text('Local Network (LAN)'), findsOneWidget);
      expect(find.text('Remote Webserver (Cloud)'), findsOneWidget);
      expect(find.text('Save & Apply Server Settings'), findsOneWidget);
      expect(find.text('Test Connection (/health)'), findsOneWidget);
    });

    testWidgets('Switching to Remote Webserver updates URL to cloud default', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ServerSettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Webserver Card
      await tester.tap(find.text('Remote Webserver (Cloud)'));
      await tester.pumpAndSettle();

      // Verify Webserver URL field is shown
      expect(find.text('Remote Webserver URL'), findsOneWidget);
      expect(find.text('https://api.roomlyst.com'), findsWidgets);
    });

    testWidgets('Saving custom URL updates AppConfig and persists in SharedPreferences', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ServerSettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter a custom URL
      final textField = find.byKey(const Key('server_url_input'));
      expect(textField, findsOneWidget);
      await tester.enterText(textField, 'http://192.168.1.100:8000');
      await tester.pump();

      // Tap Save
      await tester.tap(find.text('Save & Apply Server Settings'));
      await tester.pumpAndSettle();

      // Verify AppConfig is updated
      expect(AppConfig.baseUrl, equals('http://192.168.1.100:8000'));
      expect(AppConfig.serverType, equals('local'));

      // Verify SharedPreferences has the saved value
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConfig.keyActiveBaseUrl), equals('http://192.168.1.100:8000'));
    });

    test('ApiClient token persistence preserves login across restarts', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await ApiClient.getToken(), isNull);

      await ApiClient.saveToken('jwt_session_token_xyz_2026');
      expect(await ApiClient.getToken(), equals('jwt_session_token_xyz_2026'));

      // Simulate re-reading from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final restored = prefs.getString(ApiClient.tokenKey);
      expect(restored, equals('jwt_session_token_xyz_2026'));

      // Clear token
      await ApiClient.clearToken();
      expect(await ApiClient.getToken(), isNull);
    });
  });
}
