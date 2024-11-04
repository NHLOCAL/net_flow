import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:net_flow/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // בונה את האפליקציה באמצעות MyBrowserApp במקום MyApp
    await tester.pumpWidget(MyBrowserApp());

    // ביצוע בדיקות נוספות כהרגלך
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // סימולציה של לחיצה על כפתור ההוספה
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // בדיקה שהתוצאה עודכנה
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
