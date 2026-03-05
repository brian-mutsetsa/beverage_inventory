import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beverage_inventory/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AuraApp());

    // Verify that the app starts with Dashboard screen
    expect(find.text('Dashboard'), findsOneWidget);
  });
}