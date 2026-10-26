import 'package:fittrack/src/screens/ai/ai_assistant_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AI screen opens without eagerly constructing the Firebase model', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AiAssistantScreen()),
    );
    await tester.pump();

    expect(find.byType(AiAssistantScreen), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
  });
}
