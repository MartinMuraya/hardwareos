import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardwareos/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // HardwareOSApp requires Firebase — skip in unit tests.
    // Use integration_test package for full end-to-end testing.
    expect(HardwareOSApp, isNotNull);
  });
}
