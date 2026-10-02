import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sto_rosario_parish_church/features/ai_chat/screens/ai_chat_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('restores and clears local chat history', (tester) async {
    SharedPreferences.setMockInitialValues({
      'parish_ai_chat_history_v1': jsonEncode([
        {
          'text': 'Saved question',
          'isUser': true,
          'createdAt': '2026-09-28T10:00:00.000',
        },
        {
          'text': 'Saved answer',
          'isUser': false,
          'createdAt': '2026-09-28T10:01:00.000',
        },
      ]),
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 400, height: 700, child: AIChatScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved question'), findsOneWidget);
    expect(find.text('Saved answer'), findsOneWidget);
    expect(find.text("Hello! 👋 I'm the Parish AI Assistant."), findsNothing);
    expect(
      tester.getTopLeft(find.text('Saved question')).dy,
      lessThan(tester.getTopLeft(find.text('Saved answer')).dy),
    );

    await tester.tap(find.byTooltip('Chat options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Chat'));
    await tester.pumpAndSettle();
    expect(find.text('Clear conversation?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Clear Chat'));
    await tester.pumpAndSettle();

    expect(find.text('Saved question'), findsNothing);
    expect(find.text("Hello! 👋 I'm the Parish AI Assistant."), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).containsKey(
        'parish_ai_chat_history_v1',
      ),
      isFalse,
    );
  });
}
