import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_mhproj/data/mindwell_repository.dart';
import 'package:flutter_application_mhproj/features/clinic/presentation/clinic_dashboard_page.dart';

import 'helpers/widget_test_utils.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    binding.window.physicalSizeTestValue = const Size(1280, 2400);
    binding.window.devicePixelRatioTestValue = 1.0;
    MindWellRepository.instance.seed();
  });

  tearDown(() {
    binding.window.clearPhysicalSizeTestValue();
    binding.window.clearDevicePixelRatioTestValue();
  });

  testWidgets('filters patients by search query', (tester) async {
    await pumpProviderApp(
      tester,
      ClinicDashboardPage(onThemeChanged: (_) {}),
    );

    expect(find.text('Alice Tan'), findsOneWidget);
    expect(find.text('Ben Wong'), findsOneWidget);

    final searchField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == 'Search patient name/email',
    );

    await tester.enterText(searchField, 'ben');
    await tester.pump(Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Ben Wong'), findsOneWidget);
    expect(find.text('Alice Tan'), findsNothing);
  }, skip: true);

  testWidgets('sorting toggle changes patient order', (tester) async {
    await pumpProviderApp(
      tester,
      ClinicDashboardPage(onThemeChanged: (_) {}),
    );

    final alicePositionBefore = tester.getTopLeft(find.byKey(ValueKey('u1')));
    final benPositionBefore = tester.getTopLeft(find.byKey(const ValueKey('u2')));
    expect(alicePositionBefore.dy, lessThan(benPositionBefore.dy));

    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ascending'));
    await tester.pumpAndSettle();

    final alicePositionAfter = tester.getTopLeft(find.byKey(const ValueKey('u1')));
    final benPositionAfter = tester.getTopLeft(find.byKey(const ValueKey('u2')));
    expect(alicePositionAfter.dy, greaterThan(benPositionAfter.dy));
  }, skip: true);
}
