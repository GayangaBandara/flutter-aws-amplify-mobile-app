// This is a basic Flutter widget test for Voice AI Assistant.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hello_world_app_flutter/main.dart';

void main() {
  testWidgets('Voice AI Assistant app loads correctly', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(VoiceAIApp());

    // Verify that the app title is displayed
    expect(find.text('Voice AI Assistant'), findsOneWidget);

    // Verify that the microphone button is present
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // Verify the empty state message
    expect(find.text('Tap the microphone to start'), findsOneWidget);
  });
}
