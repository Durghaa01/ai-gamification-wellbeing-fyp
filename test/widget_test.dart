// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_mhproj/main.dart';
import 'package:flutter_application_mhproj/core/providers/app_providers.dart';
import 'package:flutter_application_mhproj/services/identity/identity_service.dart';

import 'helpers/test_bootstrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await ensureTestStoreInitialized(reset: true);
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('MindWell app renders landing page', (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    final identityService = IdentityService(preferences: prefs);
    final visitorId = await identityService.ensureVisitorId();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityServiceProvider.overrideWithValue(identityService),
          visitorIdProvider.overrideWith((ref) => visitorId),
        ],
        child: const MindWellApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('MindWell'), findsWidgets);
  }, skip: true);
}
