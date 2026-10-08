import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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


class FakeHistoryWebViewController extends Fake
    implements InAppWebViewController {
  FakeHistoryWebViewController({
    required this.urls,
    required this.currentIndex,
  });

  final List<String> urls;
  int currentIndex;
  int backCalls = 0;
  int forwardCalls = 0;
  Completer<bool>? pendingBackAvailability;

  void visit(String url) {
    urls.removeRange(currentIndex + 1, urls.length);
    urls.add(url);
    currentIndex = urls.length - 1;
  }

  @override
  Future<WebHistory?> getCopyBackForwardList() async {
    return WebHistory(
      currentIndex: currentIndex,
      list: [
        for (var i = 0; i < urls.length; i++)
          WebHistoryItem(index: i, url: WebUri(urls[i])),
      ],
    );
  }

  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    WebUri? allowingReadAccessTo,
    Uri? iosAllowingReadAccessTo,
  }) async {
    final newUrl = urlRequest.url?.toString();
    if (newUrl == null) {
      return;
    }
    visit(newUrl);
  }

  @override
  Future<void> goBack() async {
    backCalls++;
    if (currentIndex > 0) {
      currentIndex--;
    }
  }

  @override
  Future<void> goForward() async {
    forwardCalls++;
    if (currentIndex < urls.length - 1) {
      currentIndex++;
    }
  }

  @override
  Future<bool> canGoBack() async {
    final delayed = pendingBackAvailability;
    if (delayed != null) {
      pendingBackAvailability = null;
      return delayed.future;
    }
    return currentIndex > 0;
  }

  @override
  Future<bool> canGoForward() async => currentIndex < urls.length - 1;

  @override
  Future<WebUri?> getUrl() async => WebUri(urls[currentIndex]);

  @override
  Future<String?> getTitle() async => 'Page ${currentIndex + 1}';
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

  testWidgets('home displays the packaged app icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompactBrowserPage(
          androidChannel: FakeAndroidBrowserChannel(),
          webViewOverride: const SizedBox(key: Key('fake-webview')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(
      find.byKey(const Key('browser-home-app-icon')),
    );
    expect(image.image, isA<AssetImage>());
    expect((image.image as AssetImage).assetName, 'assets/icon_launcher.png');

    final iconCenter = tester.getCenter(
      find.byKey(const Key('browser-home-app-icon')),
    );
    final titleCenter = tester.getCenter(find.text('Net Flow'));
    expect(find.byKey(const Key('browser-home-brand-row')), findsOneWidget);
    expect((iconCenter.dy - titleCenter.dy).abs(), lessThan(1));
    expect(iconCenter.dx, greaterThan(titleCenter.dx));
  });

  testWidgets('home does not overflow in a short viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 250);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: CompactBrowserPage(
          androidChannel: FakeAndroidBrowserChannel(),
          webViewOverride: const SizedBox(key: Key('fake-webview')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('browser-home-app-icon')), findsOneWidget);
    expect(find.byKey(const Key('browser-home-search-field')), findsOneWidget);
    final icon = tester.getCenter(
      find.byKey(const Key('browser-home-app-icon')),
    );
    final title = tester.getCenter(find.text('Net Flow'));
    expect((icon.dy - title.dy).abs(), lessThan(1));
    expect(icon.dx, greaterThan(title.dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home search field uses a sharp linear style', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompactBrowserPage(
          androidChannel: FakeAndroidBrowserChannel(),
          webViewOverride: const SizedBox(key: Key('fake-webview')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('browser-home-search-field')),
    );
    final border = field.decoration?.border;

    expect(field.style?.fontWeight, FontWeight.w500);
    expect(border, isA<UnderlineInputBorder>());
  });

  testWidgets(
    'home search shows recent history and matching bookmark suggestions',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'search_history': jsonEncode(['netfree status', 'example.com']),
        'bookmarks': jsonEncode([
          {'title': 'Netfree', 'url': 'https://netfree.link'},
          {'title': 'Flutter', 'url': 'https://flutter.dev'},
        ]),
      });

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
        'net',
      );
      await tester.pump();

      expect(
        find.byKey(const Key('browser-home-suggestions-panel')),
        findsOneWidget,
      );
      expect(find.text('netfree status'), findsOneWidget);
      expect(find.text('Netfree'), findsOneWidget);
      expect(find.text('Flutter'), findsNothing);

      await tester.tap(find.text('Netfree'));
      await tester.pump();

      expect(find.byKey(const Key('fake-webview')), findsOneWidget);
      expect(find.byKey(const Key('browser-home-search-field')), findsNothing);
    },
  );

  testWidgets('home search clear button closes suggestions', (tester) async {
    SharedPreferences.setMockInitialValues({
      'search_history': jsonEncode(['netfree status', 'example.com']),
    });

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
      'net',
    );
    await tester.pump();
    expect(
      find.byKey(const Key('browser-home-suggestions-panel')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('נקה'));
    await tester.pump();

    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('browser-home-search-field')),
          )
          .controller
          ?.text,
      isEmpty,
    );
    expect(
      find.byKey(const Key('browser-home-suggestions-panel')),
      findsNothing,
    );
  });

  testWidgets('home search submission saves newest entries first', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'search_history': jsonEncode(['old search']),
    });

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
      'new search',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    final preferences = await SharedPreferences.getInstance();
    final rawHistory = preferences.getString('search_history')!;

    expect(jsonDecode(rawHistory), ['new search', 'old search']);
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
    for (var index = 0; index < 4; index += 1) {
      expect(
        find.byKey(Key('browser-bottom-bar-separator-$index')),
        findsOneWidget,
      );
    }

    final home =
        tester.getTopLeft(find.byKey(const Key('browser-home-button')));
    final reload =
        tester.getTopLeft(find.byKey(const Key('browser-reload-button')));
    final forward =
        tester.getTopLeft(find.byKey(const Key('browser-forward-button')));
    final back =
        tester.getTopLeft(find.byKey(const Key('browser-back-button')));
    final menu =
        tester.getTopLeft(find.byKey(const Key('browser-menu-button')));

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

  testWidgets('home search field switches direction by typed language', (
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

    await tester.enterText(
      find.byKey(const Key('browser-home-search-field')),
      'בדיקת נטפרי',
    );
    await tester.pump();

    TextField field = tester.widget(
      find.byKey(const Key('browser-home-search-field')),
    );
    expect(field.textDirection, TextDirection.rtl);
    expect(field.textAlign, TextAlign.right);

    await tester.enterText(
      find.byKey(const Key('browser-home-search-field')),
      'example.com',
    );
    await tester.pump();

    field = tester.widget(find.byKey(const Key('browser-home-search-field')));
    expect(field.textDirection, TextDirection.ltr);
    expect(field.textAlign, TextAlign.left);
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

  testWidgets('home button works while a page is still loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompactBrowserPage(
          androidChannel: FakeAndroidBrowserChannel(),
          initialState: const BrowserState(
            currentUrl: 'https://example.com',
            isLoading: true,
          ),
          webViewOverride: const SizedBox(key: Key('fake-webview')),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('fake-webview')), findsOneWidget);
    await tester.tap(find.byKey(const Key('browser-home-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('browser-home-search-field')), findsOneWidget);
    expect(find.byKey(const Key('fake-webview')), findsNothing);
  });

  testWidgets('a new search works while the previous site loads', (
    tester,
  ) async {
    final channel = FakeAndroidBrowserChannel();
    await tester.pumpWidget(
      MaterialApp(
        home: CompactBrowserPage(
          androidChannel: channel,
          initialState: const BrowserState(
            currentUrl: 'https://example.com',
            isLoading: true,
          ),
          webViewOverride: const SizedBox(key: Key('fake-webview')),
        ),
      ),
    );
    await tester.pump();

    await channel.openUrlHandler?.call('new search');
    await tester.pump();

    expect(find.byKey(const Key('fake-webview')), findsOneWidget);
    expect(find.byKey(const Key('browser-bottom-bar')), findsOneWidget);
  });

  testWidgets('about:blank is a browser page, not an app error or home', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompactBrowserPage(
          androidChannel: FakeAndroidBrowserChannel(),
          initialState: const BrowserState(currentUrl: 'about:blank'),
          webViewOverride: const SizedBox(key: Key('fake-webview')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fake-webview')), findsOneWidget);
    expect(find.byKey(const Key('browser-home-search-field')), findsNothing);
  });

  testWidgets('slow loads remain in WebView past 12 seconds', (tester) async {
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
    await tester.pump();

    expect(find.byKey(const Key('fake-webview')), findsOneWidget);
    await tester.pump(const Duration(seconds: 13));

    expect(find.byKey(const Key('fake-webview')), findsOneWidget);
    expect(find.byKey(const Key('browser-home-search-field')), findsNothing);
  });
  testWidgets('back and forward follow the native WebView history', (
    tester,
  ) async {
    final controller = FakeHistoryWebViewController(
      urls: const [
        'https://one.test/',
        'https://two.test/',
        'https://three.test/',
      ],
      currentIndex: 2,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CompactBrowserPage(
          androidChannel: FakeAndroidBrowserChannel(),
          webViewOverride: const SizedBox(key: Key('fake-webview')),
          webViewControllerOverride: controller,
          initialState: const BrowserState(
            currentUrl: 'https://three.test/',
            canGoBack: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('browser-back-button')));
    await tester.pump();
    expect(controller.currentIndex, 1);
    expect(controller.backCalls, 1);
    // No load-stop callbacks occur for same-document (SPA) navigation.
    // The toolbar must not remain stuck on its loading/stop state.
    expect(find.byTooltip('רענן'), findsOneWidget);
    expect(find.byTooltip('עצור'), findsNothing);
    expect(
      tester.widget<InkWell>(find.descendant(
        of: find.byKey(const Key('browser-forward-button')),
        matching: find.byType(InkWell),
      )).onTap,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('browser-back-button')));
    await tester.pump();
    expect(controller.currentIndex, 0);
    expect(
      tester.widget<InkWell>(find.descendant(
        of: find.byKey(const Key('browser-back-button')),
        matching: find.byType(InkWell),
      )).onTap,
      isNull,
    );

    await tester.tap(find.byKey(const Key('browser-forward-button')));
    await tester.pump();
    expect(controller.currentIndex, 1);
    expect(controller.forwardCalls, 1);
    expect(
      tester.widget<InkWell>(find.descendant(
        of: find.byKey(const Key('browser-back-button')),
        matching: find.byType(InkWell),
      )).onTap,
      isNotNull,
    );
  });

  testWidgets('back reopens an intentionally revisited older page', (
    tester,
  ) async {
    final controller = FakeHistoryWebViewController(
      urls: <String>[
        'https://one.test/',
        'https://two.test/',
      ],
      currentIndex: 1,
    );
    final channel = FakeAndroidBrowserChannel();
    await tester.pumpWidget(
      MaterialApp(
        home: CompactBrowserPage(
          androidChannel: channel,
          webViewOverride: const SizedBox(key: Key('fake-webview')),
          webViewControllerOverride: controller,
          initialState: const BrowserState(
            currentUrl: 'https://two.test/',
            canGoBack: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // This address-bar navigation marks page two as superseded.
    await channel.openUrlHandler?.call('https://three.test/');
    await tester.pump();
    expect(controller.currentIndex, 2);

    // Back must explicitly reauthorize the old URL, not reject it as stale.
    await tester.tap(find.byKey(const Key('browser-back-button')));
    await tester.pump();
    expect(controller.currentIndex, 1);
    expect(controller.backCalls, 1);

    await tester.tap(find.byKey(const Key('browser-forward-button')));
    await tester.pump();
    expect(controller.currentIndex, 2);
    expect(controller.forwardCalls, 1);
  });

  testWidgets('rapid back taps are processed in order', (tester) async {
    final controller = FakeHistoryWebViewController(
      urls: const [
        'https://one.test/',
        'https://two.test/',
        'https://three.test/',
      ],
      currentIndex: 2,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CompactBrowserPage(
          androidChannel: FakeAndroidBrowserChannel(),
          webViewOverride: const SizedBox(key: Key('fake-webview')),
          webViewControllerOverride: controller,
          initialState: const BrowserState(
            currentUrl: 'https://three.test/',
            canGoBack: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('browser-back-button')));
    await tester.tap(find.byKey(const Key('browser-back-button')));
    await tester.pump();
    expect(controller.currentIndex, 0);
    expect(controller.backCalls, 2);
  });

  testWidgets('a new address cancels a pending back command', (
    tester,
  ) async {
    final controller = FakeHistoryWebViewController(
      urls: <String>[
        'https://one.test/',
        'https://two.test/',
        'https://three.test/',
      ],
      currentIndex: 2,
    );
    final channel = FakeAndroidBrowserChannel();
    final pending = Completer<bool>();
    controller.pendingBackAvailability = pending;

    await tester.pumpWidget(
      MaterialApp(
        home: CompactBrowserPage(
          androidChannel: channel,
          webViewOverride: const SizedBox(key: Key('fake-webview')),
          webViewControllerOverride: controller,
          initialState: const BrowserState(
            currentUrl: 'https://three.test/',
            canGoBack: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('browser-back-button')));
    await tester.pump();

    // Navigate to a new address while the native history snapshot is pending.
    await channel.openUrlHandler?.call('https://new.test/');
    await tester.pump();
    expect(controller.currentIndex, 3);

    pending.complete(true);
    await tester.pump();
    await tester.pump();

    expect(controller.backCalls, 0);
    expect(controller.currentIndex, 3);
  });

  testWidgets('new back taps bypass a canceled stalled history query', (
    tester,
  ) async {
    final controller = FakeHistoryWebViewController(
      urls: <String>[
        'https://one.test/',
        'https://two.test/',
        'https://three.test/',
      ],
      currentIndex: 2,
    );
    final channel = FakeAndroidBrowserChannel();
    final staleQuery = Completer<bool>();
    controller.pendingBackAvailability = staleQuery;
    await tester.pumpWidget(
      MaterialApp(
        home: CompactBrowserPage(
          androidChannel: channel,
          webViewOverride: const SizedBox(key: Key('fake-webview')),
          webViewControllerOverride: controller,
          initialState: const BrowserState(
            currentUrl: 'https://three.test/',
            canGoBack: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('browser-back-button')));
    await tester.pump();
    expect(controller.backCalls, 0);

    // The old WebView history query is still awaiting its response.
    await channel.openUrlHandler?.call('https://new.test/');
    await tester.pump();
    expect(controller.currentIndex, 3);

    // Back on the NEW page must work without waiting for the OLD query.
    await tester.tap(find.byKey(const Key('browser-back-button')));
    await tester.pump();
    await tester.pump();
    expect(controller.backCalls, 1);
    expect(controller.currentIndex, 2);

    // Resolving the abandoned query must not perform a second back.
    staleQuery.complete(true);
    await tester.pump();
    expect(controller.backCalls, 1);
    expect(controller.currentIndex, 2);
  });

  testWidgets('no history navigation happens outside native boundaries', (
    tester,
  ) async {
    final controller = FakeHistoryWebViewController(
      urls: const ['https://only.test/'],
      currentIndex: 0,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CompactBrowserPage(
          androidChannel: FakeAndroidBrowserChannel(),
          webViewOverride: const SizedBox(key: Key('fake-webview')),
          webViewControllerOverride: controller,
          initialState: const BrowserState(
            currentUrl: 'https://only.test/',
            canGoBack: false,
            canGoForward: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<InkWell>(find.descendant(
        of: find.byKey(const Key('browser-back-button')),
        matching: find.byType(InkWell),
      )).onTap,
      isNull,
    );
    expect(
      tester.widget<InkWell>(find.descendant(
        of: find.byKey(const Key('browser-forward-button')),
        matching: find.byType(InkWell),
      )).onTap,
      isNull,
    );
    expect(controller.backCalls, 0);
    expect(controller.forwardCalls, 0);
  });

  testWidgets('Google redirect and clicked link update address and bookmark',
      (tester) async {
    final events = BrowserWebViewTestEvents();
    final controller = FakeHistoryWebViewController(
      urls: <String>['https://google.com/'],
      currentIndex: 0,
    );
    await tester.pumpWidget(MaterialApp(
      home: CompactBrowserPage(
        androidChannel: FakeAndroidBrowserChannel(),
        webViewOverride: const SizedBox(key: Key('fake-webview')),
        webViewControllerOverride: controller,
        webViewTestEvents: events,
        initialState: const BrowserState(currentUrl: 'https://google.com/'),
      ),
    ));
    await tester.pumpAndSettle();

    controller.urls[0] = 'https://www.google.com/';
    events.loadStarted?.call('https://www.google.com/');
    events.loadStopped?.call('https://www.google.com/');
    await tester.pumpAndSettle();

    const article = 'https://example.org/articles/real-page?ref=google';
    controller.visit(article);
    events.loadStarted?.call(article);
    events.visitedHistory?.call(article);
    events.loadStopped?.call(article);
    await tester.pumpAndSettle();

    expect(
      tester.widget<InkWell>(find.descendant(
        of: find.byKey(const Key('browser-back-button')),
        matching: find.byType(InkWell),
      )).onTap,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('browser-menu-button')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(
        find.byKey(const Key('browser-address-field')),
      ).controller?.text,
      article,
    );
    await tester.tap(find.text('שמור'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    final bookmarks = jsonDecode(
      preferences.getString('bookmarks')!,
    ) as List<dynamic>;
    expect((bookmarks.first as Map<String, dynamic>)['url'], article);

    await tester.tap(find.byKey(const Key('browser-back-button')));
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 0);
    expect(controller.backCalls, 1);
    await tester.tap(find.byKey(const Key('browser-forward-button')));
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 1);
    expect(controller.forwardCalls, 1);
  });

  testWidgets('bookmark reads native page even before its callback arrives',
      (tester) async {
    final controller = FakeHistoryWebViewController(
      urls: <String>['https://google.com/'],
      currentIndex: 0,
    );
    await tester.pumpWidget(MaterialApp(
      home: CompactBrowserPage(
        androidChannel: FakeAndroidBrowserChannel(),
        webViewOverride: const SizedBox(key: Key('fake-webview')),
        webViewControllerOverride: controller,
        initialState: const BrowserState(currentUrl: 'https://google.com/'),
      ),
    ));
    await tester.pumpAndSettle();

    const realPage = 'https://news.example.org/new-article';
    controller.visit(realPage);
    await tester.tap(find.byKey(const Key('browser-menu-button')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(
        find.byKey(const Key('browser-address-field')),
      ).controller?.text,
      realPage,
    );
    await tester.tap(find.text('שמור'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    final bookmarks = jsonDecode(
      preferences.getString('bookmarks')!,
    ) as List<dynamic>;
    expect((bookmarks.first as Map<String, dynamic>)['url'], realPage);
  });

  testWidgets('SPA visited-history updates location without document load',
      (tester) async {
    final events = BrowserWebViewTestEvents();
    final controller = FakeHistoryWebViewController(
      urls: <String>['https://example.org/app'],
      currentIndex: 0,
    );
    await tester.pumpWidget(MaterialApp(
      home: CompactBrowserPage(
        androidChannel: FakeAndroidBrowserChannel(),
        webViewOverride: const SizedBox(key: Key('fake-webview')),
        webViewControllerOverride: controller,
        webViewTestEvents: events,
        initialState: const BrowserState(currentUrl: 'https://example.org/app'),
      ),
    ));
    await tester.pumpAndSettle();

    const pushedUrl = 'https://example.org/app#chapter-two';
    controller.visit(pushedUrl);
    events.visitedHistory?.call(pushedUrl);
    await tester.pumpAndSettle();

    expect(find.byTooltip('רענן'), findsOneWidget);
    await tester.tap(find.byKey(const Key('browser-menu-button')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(
        find.byKey(const Key('browser-address-field')),
      ).controller?.text,
      pushedUrl,
    );
  });

}
