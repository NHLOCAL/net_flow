import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:net_flow/browser/widgets/compact_browser_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('compact browser renders fake webview and menu button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CompactBrowserPage(
          webViewOverride: SizedBox(key: Key('fake-webview')),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('fake-webview')), findsOneWidget);
    expect(find.byKey(const Key('browser-menu-button')), findsOneWidget);
  });

  testWidgets('menu opens a compact address sheet', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CompactBrowserPage(
          webViewOverride: SizedBox(key: Key('fake-webview')),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('browser-menu-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('browser-address-field')), findsOneWidget);
    expect(find.text('חיפוש או כתובת אתר'), findsOneWidget);
    expect(find.text('הרשאות'), findsOneWidget);
    expect(find.text('הורדות'), findsOneWidget);
  });
}
