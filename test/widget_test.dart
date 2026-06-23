import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Flutter widget test environment is available', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Kofficer Guide')),
      ),
    );

    expect(find.text('Kofficer Guide'), findsOneWidget);
  });
}
