import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ostoya/main.dart';

void main() {
  testWidgets('Timer UI renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: OstoyaApp()));

    // Verify app bar title
    expect(find.text('Meditation Timer'), findsOneWidget);

    // Verify initial time (Dummy plan is 10s prep initially)
    expect(find.text('00:10'), findsOneWidget);
    
    // Play button exists
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });
}
