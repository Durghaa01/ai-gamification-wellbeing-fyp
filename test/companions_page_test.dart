import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_mhproj/features/companions/presentation/companions_page.dart';
import 'package:flutter_application_mhproj/services/companion_api.dart';
import 'package:flutter_application_mhproj/services/companion_memory.dart';
import 'package:flutter_application_mhproj/features/companions/application/companion_controller.dart';
import 'package:flutter_application_mhproj/services/companion_data_service.dart';
import 'package:flutter_application_mhproj/models/assessment.dart';
import 'package:flutter_application_mhproj/core/providers/app_providers.dart';

import 'helpers/widget_test_utils.dart';

void main() {
  SharedPreferences.setMockInitialValues({});
  group('CompanionsPage', () {
    testWidgets('renders for registered user', (tester) async {
      _setScreenSize(tester);
      await tester.pumpWidget(
        wrapWithMaterialAppAndProviders(
          const CompanionsPage(
            isDarkMode: false,
            onThemeChanged: _noOp,
            isRegistered: true,
            sessionKey: 'test-user',
          ),
          overrides: [
            companionApiProvider.overrideWithValue(LocalCompanionApi()),
            companionMemoryStoreProvider.overrideWithValue(
              CompanionMemoryStore(),
            ),
            companionDataServiceProvider.overrideWithValue(
              FakeCompanionDataService(),
            ),
          ],
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Companions'), findsOneWidget);
      expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
    });

    testWidgets('renders for guest user', (tester) async {
      _setScreenSize(tester);

      await tester.pumpWidget(
        wrapWithMaterialAppAndProviders(
          const CompanionsPage(
            isDarkMode: false,
            onThemeChanged: _noOp,
            isRegistered: false,
          ),
          overrides: [
            companionApiProvider.overrideWithValue(LocalCompanionApi()),
            companionMemoryStoreProvider.overrideWithValue(
              CompanionMemoryStore(),
            ),
          ],
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Guest mode should show preview banner
      expect(find.textContaining('Preview'), findsOneWidget);
    });

    testWidgets('displays companion selector', (tester) async {
      _setScreenSize(tester);
      await tester.pumpWidget(
        wrapWithMaterialAppAndProviders(
          const CompanionsPage(
            isDarkMode: false,
            onThemeChanged: _noOp,
            isRegistered: true,
            sessionKey: 'test-user',
          ),
          overrides: [
            companionApiProvider.overrideWithValue(LocalCompanionApi()),
            companionMemoryStoreProvider.overrideWithValue(
              CompanionMemoryStore(),
            ),
          ],
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Should display companion names
      expect(find.text('Listener'), findsWidgets);
      expect(find.text('Coach'), findsWidgets);
      expect(find.text('Planner'), findsWidgets);
      expect(find.text('Cheerleader'), findsWidgets);
    });

    testWidgets('can send a message', (tester) async {
      _setScreenSize(tester);
      await tester.pumpWidget(
        wrapWithMaterialAppAndProviders(
          const CompanionsPage(
            isDarkMode: false,
            onThemeChanged: _noOp,
            isRegistered: true,
            sessionKey: 'test-user',
          ),
          overrides: [
            companionApiProvider.overrideWithValue(LocalCompanionApi()),
            companionMemoryStoreProvider.overrideWithValue(
              CompanionMemoryStore(),
            ),
          ],
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Find input field and enter text
      final inputField = find.byType(TextField);
      expect(inputField, findsOneWidget);

      await tester.enterText(inputField, 'I need help today');
      await tester.pump();

      // Find and tap send button
      final sendButton = find.widgetWithIcon(FilledButton, Icons.send_rounded);
      expect(sendButton, findsOneWidget);

      await tester.tap(sendButton);
      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      await tester.pump(const Duration(seconds: 2));

      // Message should appear
      expect(find.text('I need help today'), findsOneWidget);
    });

    testWidgets('shows typing indicator while loading', (tester) async {
      _setScreenSize(tester);
      await tester.pumpWidget(
        wrapWithMaterialAppAndProviders(
          const CompanionsPage(
            isDarkMode: false,
            onThemeChanged: _noOp,
            isRegistered: true,
            sessionKey: 'test-user',
          ),
          overrides: [
            companionApiProvider.overrideWithValue(LocalCompanionApi()),
            companionMemoryStoreProvider.overrideWithValue(
              CompanionMemoryStore(),
            ),
          ],
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      final inputField = find.byType(TextField);
      await tester.enterText(inputField, 'Test message');

      final sendButton = find.widgetWithIcon(FilledButton, Icons.send_rounded);
      await tester.tap(sendButton);
      await tester.pump();

      // Should show typing indicator during response generation
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('displays welcome message initially', (tester) async {
      _setScreenSize(tester);
      await tester.pumpWidget(
        wrapWithMaterialAppAndProviders(
          const CompanionsPage(
            isDarkMode: false,
            onThemeChanged: _noOp,
            isRegistered: true,
            sessionKey: 'test-user',
          ),
          overrides: [
            companionApiProvider.overrideWithValue(LocalCompanionApi()),
            companionMemoryStoreProvider.overrideWithValue(
              CompanionMemoryStore(),
            ),
          ],
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Should show empty state or welcome message
      expect(find.textContaining('Hi~ I am Listener'), findsOneWidget);
    });

    testWidgets('theme toggle works', (tester) async {
      _setScreenSize(tester);
      bool darkMode = false;

      await tester.pumpWidget(
        wrapWithMaterialAppAndProviders(
          CompanionsPage(
            isDarkMode: darkMode,
            onThemeChanged: (value) {
              darkMode = value;
            },
            isRegistered: true,
            sessionKey: 'test-user',
          ),
          overrides: [
            companionApiProvider.overrideWithValue(LocalCompanionApi()),
            companionMemoryStoreProvider.overrideWithValue(
              CompanionMemoryStore(),
            ),
          ],
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      final themeSwitch = find.byType(Switch);
      expect(themeSwitch, findsOneWidget);

      await tester.tap(themeSwitch);
      expect(darkMode, isTrue);
    });

    testWidgets('session manager button shows for registered users', (
      tester,
    ) async {
      _setScreenSize(tester);
      await tester.pumpWidget(
        wrapWithMaterialAppAndProviders(
          const CompanionsPage(
            isDarkMode: false,
            onThemeChanged: _noOp,
            isRegistered: true,
            sessionKey: 'test-user',
          ),
          overrides: [
            companionApiProvider.overrideWithValue(LocalCompanionApi()),
            companionMemoryStoreProvider.overrideWithValue(
              CompanionMemoryStore(),
            ),
          ],
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
      expect(find.byTooltip('Manage sessions'), findsOneWidget);
    });

    testWidgets('session manager button hidden for guests', (tester) async {
      _setScreenSize(tester);

      await tester.pumpWidget(
        wrapWithMaterialAppAndProviders(
          const CompanionsPage(
            isDarkMode: false,
            onThemeChanged: _noOp,
            isRegistered: false,
          ),
          overrides: [
            companionApiProvider.overrideWithValue(LocalCompanionApi()),
            companionMemoryStoreProvider.overrideWithValue(
              CompanionMemoryStore(),
            ),
          ],
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.forum_outlined), findsNothing);
    });
  });
}

void _noOp(bool value) {}

void _setScreenSize(WidgetTester tester) {
  print('DEBUG: Setting screen size');
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class FakeCompanionDataService extends CompanionDataService {
  @override
  Future<void> recordMessage({
    required String userId,
    required String sessionId,
    required String companionId,
    required String companionName,
    required AssessmentMessage message,
    String? sessionSummary,
  }) async {
    // No-op
  }
}
