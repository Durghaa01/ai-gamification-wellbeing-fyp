import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_mhproj/features/landing/presentation/mindwell_landing_page.dart';

import 'helpers/widget_test_utils.dart';

void main() {
  testWidgets(
    'AI Chatbot triggers preview without login prompt',
    (tester) async {
    var previewCalled = false;
    var loginCalled = false;

    await pumpProviderApp(
      tester,
      MindWellLandingPage(
        onOpenBooking: () {},
        onOpenLogin: () {
          loginCalled = true;
        },
        onOpenCompanionsPreview: () {
          previewCalled = true;
        },
      ),
    );

    await tester.scrollUntilVisible(find.text('AI Chatbot'), 500);
    await tester.tap(find.text('AI Chatbot'));
    await tester.pumpAndSettle();

    expect(previewCalled, isTrue);
    expect(loginCalled, isFalse);
    expect(find.text('Login Required'), findsNothing);
    },
    skip: true,
  );

  testWidgets(
    'appointments shortcut invokes booking callback',
    (tester) async {
    var bookingCalled = false;

    await pumpProviderApp(
      tester,
      MindWellLandingPage(
        onOpenBooking: () {
          bookingCalled = true;
        },
        onOpenLogin: () {},
        onOpenCompanionsPreview: () {},
      ),
    );

    await tester.scrollUntilVisible(find.text('Appointments'), 500);
    await tester.tap(find.text('Appointments'));
    await tester.pumpAndSettle();

    expect(bookingCalled, isTrue);
    },
    skip: true,
  );
}
