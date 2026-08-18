import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_bootstrap.dart';

/// Wraps a widget with MaterialApp and ProviderScope for testing.
Widget wrapWithMaterialAppAndProviders(
  Widget child, {
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

Future<void> pumpProviderApp(
  WidgetTester tester,
  Widget child,
) async {
  await ensureTestStoreInitialized();
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1280, 2400);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}
