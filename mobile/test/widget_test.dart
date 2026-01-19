// Basic Flutter widget test for Scenic Walk app.

import 'package:flutter_test/flutter_test.dart';
import 'package:scenic_walk/main.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Note: Full tests require Firebase mock setup
    await tester.pumpWidget(const ScenicWalkApp());

    // Verify the app title appears
    expect(find.text('Scenic Walk'), findsOneWidget);
  });
}
