// Basic smoke test.
//
// The full app (MagisorApp) depends on Firebase, window_manager, and
// tray_manager plugins that aren't available in the test harness, so a full
// pump isn't meaningful here. This verifies the test toolchain compiles and
// runs; widget tests for individual screens can mock their dependencies.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a basic MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: Text('Magisor')))),
    );

    expect(find.text('Magisor'), findsOneWidget);
  });
}
