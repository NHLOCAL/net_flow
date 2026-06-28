import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:net_flow/browser/models/browser_state.dart';
import 'package:net_flow/browser/widgets/browser_menu_sheet.dart';

void main() {
  testWidgets('address submission calls onNavigate and closes the sheet', (
    tester,
  ) async {
    String? navigatedTo;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => BrowserMenuSheet(
                      state: const BrowserState(),
                      bookmarks: const [],
                      onNavigate: (value) => navigatedTo = value,
                      onBack: () {},
                      onForward: () {},
                      onReload: () {},
                      onStop: () {},
                      onHome: () {},
                      onAddBookmark: () {},
                      onOpenBookmark: (_) {},
                      onDeleteBookmark: (_) {},
                      onShowSitePermissions: () {},
                    ),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('browser-address-field')),
      'example.com',
    );
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    expect(navigatedTo, 'example.com');
    expect(find.byKey(const Key('browser-address-field')), findsNothing);
  });

  testWidgets('back and forward controls are disabled when unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowserMenuSheet(
            state: const BrowserState(canGoBack: false, canGoForward: false),
            bookmarks: const [],
            onNavigate: (_) {},
            onBack: () {},
            onForward: () {},
            onReload: () {},
            onStop: () {},
            onHome: () {},
            onAddBookmark: () {},
            onOpenBookmark: (_) {},
            onDeleteBookmark: (_) {},
            onShowSitePermissions: () {},
          ),
        ),
      ),
    );

    final back = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('חזרה'),
        matching: find.byType(OutlinedButton),
      ),
    );
    final forward = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('קדימה'),
        matching: find.byType(OutlinedButton),
      ),
    );

    expect(back.onPressed, isNull);
    expect(forward.onPressed, isNull);
  });

  testWidgets('main menu does not show a duplicate browser action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowserMenuSheet(
            state: const BrowserState(),
            bookmarks: const [],
            onNavigate: (_) {},
            onBack: () {},
            onForward: () {},
            onReload: () {},
            onStop: () {},
            onHome: () {},
            onAddBookmark: () {},
            onOpenBookmark: (_) {},
            onDeleteBookmark: (_) {},
            onShowSitePermissions: () {},
          ),
        ),
      ),
    );

    expect(find.text('בית'), findsOneWidget);
    expect(find.text('דפדפן'), findsNothing);
  });
}
