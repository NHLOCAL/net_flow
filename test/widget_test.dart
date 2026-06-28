import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:net_flow/browser/models/browser_error.dart';
import 'package:net_flow/browser/models/browser_state.dart';
import 'package:net_flow/browser/services/android_browser_channel.dart';
import 'package:net_flow/browser/widgets/compact_browser_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAndroidBrowserChannel extends AndroidBrowserChannel {
  FakeAndroidBrowserChannel({this.initialUrl})
      : super(channel: const MethodChannel('net_flow/browser_test'));

  final String? initialUrl;
  Future<void> Function(String url)? openUrlHandler;

  @override
  void setOpenUrlHandler(Future<void> Function(String url) handler) {
    openUrlHandler = handler;
  }

  @override
  Future<String?> getInitialUrl() async => initialUrl;

  @override
  Future<bool> isDefaultBrowserRoleAvailable() async => false;

  @override
  Future<bool> isDefaultBrowserRoleHeld() async => false;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('compact browser renders native home and bottom navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompactBrowserPage(
          androidChannel: FakeAndroidBrowserChannel(),
          webViewOverride: const SizedBox(key: Key('fake-webview')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('browser-home-search-field')), findsOneWidget);
    expect(find.byKey(const Key('fake-webview')), findsNothing);
    expect(find.byKey(const Key('browser-bottom-bar')), findsOneWidget);
    expect(find.byKey(const Key('browser-menu-button')), findsOneWidget);
  });

  testWidgets('bottom navigation keeps core browser controls visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompactBrowserPage(
          androidChannel: FakeAndroidBrowserChannel(),
          webViewOverride: const SizedBox(key: Key('fake-webview')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('browser-home-button')), findsOneWidget);
    expect(find.byKey(const Key('browser-reload-button')), findsOneWidget);
    expect(find.byKey(const Key('browser-forward-button')), findsOneWidget);
    expect(find.byKey(const Key('browser-back-button')), findsOneWidget);
    expect(find.byKey(const Key('browser-menu-button')), findsOneWidget);

    final home = tester.getTopLeft(find.byKey(const Key('browser-home-button')));
    final reload =
        tester.getTopLeft(find.byKey(const Key('browser-reload-button')));
    final forward =
        tester.getTopLeft(find.byKey(const Key('browser-forward-button')));
    final back = tester.getTopLeft(find.byKey(const Key('browser-back-button')));
    final menu = tester.getTopLeft(find.byKey(const Key('browser-menu-button')));

    expect(home.dx, greaterThan(reload.dx));
    expect(reload.dx, greaterThan(forward.dx));
    expect(forward.dx, greaterThan(back.dx));
    expect(back.dx, greaterThan(menu.dx));
  });

  testWidgets('more button opens a compact address sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompactBrowserPage(
          androidChannel: FakeAndroidBrowserChannel(),
          webViewOverride: const SizedBox(key: Key('fake-webview')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('browser-menu-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('browser-address-field')), findsOneWidget);
    expect(find.text('הרשאות'), findsOneWidget);
    expect(find.text('סימניות'), findsOneWidget);
    expect(find.text('הורדות'), findsNothing);
  });

  testWidgets('home search opens the browser surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompactBrowserPage(
          androidChannel: FakeAndroidBrowserChannel(),
          webViewOverride: const SizedBox(key: Key('fake-webview')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('browser-home-search-field')),
      'example.com',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(find.byKey(const Key('fake-webview')), findsOneWidget);
    expect(find.byKey(const Key('browser-home-search-field')), findsNothing);
  });

  testWidgets('initial URL opens directly in the browser surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompactBrowserPage(
          androidChannel: FakeAndroidBrowserChannel(
            initialUrl: 'https://example.com',
          ),
          webViewOverride: const SizedBox(key: Key('fake-webview')),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('fake-webview')), findsOneWidget);
    expect(find.byKey(const Key('browser-home-search-field')), findsNothing);
  });

  testWidgets('home button leaves an error page and shows home search', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompactBrowserPage(
          androidChannel: FakeAndroidBrowserChannel(),
          initialState: BrowserState(
            currentUrl: 'https://example.com',
            error: BrowserError.blank(url: 'https://example.com'),
          ),
          webViewOverride: const SizedBox(key: Key('fake-webview')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('browser-home-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('browser-home-search-field')), findsOneWidget);
    expect(find.byKey(const Key('fake-webview')), findsNothing);
  });

  testWidgets('new search leaves an error page and opens browser surface', (
    tester,
  ) async {
    final channel = FakeAndroidBrowserChannel();
    await tester.pumpWidget(
      MaterialApp(
        home: CompactBrowserPage(
          androidChannel: channel,
          initialState: BrowserState(
            currentUrl: 'https://example.com',
            error: BrowserError.blank(url: 'https://example.com'),
          ),
          webViewOverride: const SizedBox(key: Key('fake-webview')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await channel.openUrlHandler?.call('new search');
    await tester.pump();

    expect(find.byKey(const Key('fake-webview')), findsOneWidget);
    expect(find.text('הדף נטען ריק'), findsNothing);
  });
}
