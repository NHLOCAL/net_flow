import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:net_flow/browser/models/bookmark.dart';
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

  testWidgets('clear button empties the address field', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowserMenuSheet(
            state: const BrowserState(currentUrl: 'https://example.com'),
            bookmarks: const [],
            onNavigate: (_) {},
            onAddBookmark: () {},
            onOpenBookmark: (_) {},
            onDeleteBookmark: (_) {},
            onShowSitePermissions: () {},
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('browser-address-field')),
          )
          .controller
          ?.text,
      'https://example.com',
    );
    await tester.tap(find.byKey(const Key('browser-address-clear-button')));
    await tester.pump();

    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('browser-address-field')),
          )
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('address field uses a sharp linear style', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowserMenuSheet(
            state: const BrowserState(),
            bookmarks: const [],
            onNavigate: (_) {},
            onAddBookmark: () {},
            onOpenBookmark: (_) {},
            onDeleteBookmark: (_) {},
            onShowSitePermissions: () {},
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(
      find.byKey(const Key('browser-address-field')),
    );
    final border = field.decoration?.border;

    expect(field.style?.fontWeight, FontWeight.w500);
    expect(border, isA<UnderlineInputBorder>());
  });

  testWidgets('address field switches direction from Hebrew to URL text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowserMenuSheet(
            state: const BrowserState(),
            bookmarks: const [],
            onNavigate: (_) {},
            onAddBookmark: () {},
            onOpenBookmark: (_) {},
            onDeleteBookmark: (_) {},
            onShowSitePermissions: () {},
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('browser-address-field')),
      'בדיקת נטפרי',
    );
    await tester.pump();

    TextField field = tester.widget(
      find.byKey(const Key('browser-address-field')),
    );
    expect(field.textDirection, TextDirection.rtl);
    expect(field.textAlign, TextAlign.right);

    await tester.enterText(
      find.byKey(const Key('browser-address-field')),
      'example.com',
    );
    await tester.pump();

    field = tester.widget(find.byKey(const Key('browser-address-field')));
    expect(field.textDirection, TextDirection.ltr);
    expect(field.textAlign, TextAlign.left);
  });

  testWidgets('search icon submits the address field without an arrow button', (
    tester,
  ) async {
    String? navigatedTo;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowserMenuSheet(
            state: const BrowserState(),
            bookmarks: const [],
            onNavigate: (value) => navigatedTo = value,
            onAddBookmark: () {},
            onOpenBookmark: (_) {},
            onDeleteBookmark: (_) {},
            onShowSitePermissions: () {},
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('browser-address-field')),
      'netfree.link',
    );
    await tester.tap(find.byKey(const Key('browser-address-search-button')));
    await tester.pumpAndSettle();

    expect(navigatedTo, 'netfree.link');
    expect(find.byTooltip('פתח'), findsNothing);
    expect(find.byIcon(Icons.arrow_forward), findsNothing);
  });

  testWidgets('more menu does not duplicate bottom navigation actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowserMenuSheet(
            state: const BrowserState(),
            bookmarks: const [],
            onNavigate: (_) {},
            onAddBookmark: () {},
            onOpenBookmark: (_) {},
            onDeleteBookmark: (_) {},
            onShowSitePermissions: () {},
          ),
        ),
      ),
    );

    expect(find.text('בית'), findsNothing);
    expect(find.text('רענן'), findsNothing);
    expect(find.text('קדימה'), findsNothing);
    expect(find.text('חזרה'), findsNothing);
    expect(find.text('דפדפן'), findsNothing);
    expect(find.widgetWithText(TextButton, 'שמור'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'סימניות'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'הרשאות'), findsOneWidget);
    for (var index = 0; index < 2; index += 1) {
      expect(
        find.byKey(Key('browser-menu-action-separator-$index')),
        findsOneWidget,
      );
    }
  });

  testWidgets('bookmarks open from an action button above the action row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowserMenuSheet(
            state: const BrowserState(),
            bookmarks: const [
              Bookmark(title: 'Netfree', url: 'https://netfree.link'),
            ],
            onNavigate: (_) {},
            onAddBookmark: () {},
            onOpenBookmark: (_) {},
            onDeleteBookmark: (_) {},
            onShowSitePermissions: () {},
          ),
        ),
      ),
    );

    expect(find.text('הורדות'), findsNothing);
    expect(find.text('Netfree'), findsNothing);
    expect(find.byKey(const Key('browser-bookmarks-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('browser-bookmarks-button')));
    await tester.pump();

    expect(find.text('Netfree'), findsOneWidget);
    final panelTop = tester.getTopLeft(
      find.byKey(const Key('browser-bookmarks-panel')),
    );
    final actionRowTop = tester.getTopLeft(
      find.byKey(const Key('browser-menu-action-row')),
    );
    expect(panelTop.dy, lessThan(actionRowTop.dy));
  });

  testWidgets(
      'deleting a bookmark updates the open bookmarks panel immediately', (
    tester,
  ) async {
    Bookmark? deletedBookmark;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowserMenuSheet(
            state: const BrowserState(),
            bookmarks: const [
              Bookmark(title: 'Netfree', url: 'https://netfree.link'),
              Bookmark(title: 'Example', url: 'https://example.com'),
            ],
            onNavigate: (_) {},
            onAddBookmark: () {},
            onOpenBookmark: (_) {},
            onDeleteBookmark: (bookmark) => deletedBookmark = bookmark,
            onShowSitePermissions: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('browser-bookmarks-button')));
    await tester.pump();
    expect(find.text('Netfree'), findsOneWidget);
    expect(find.text('Example'), findsOneWidget);

    await tester.tap(find.byTooltip('מחק סימניה').first);
    await tester.pump();

    expect(deletedBookmark?.title, 'Netfree');
    expect(find.text('Netfree'), findsNothing);
    expect(find.text('Example'), findsOneWidget);
  });
}
