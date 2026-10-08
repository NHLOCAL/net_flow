import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:integration_test/integration_test.dart';
import 'package:net_flow/browser/models/browser_state.dart';
import 'package:net_flow/browser/services/android_browser_channel.dart';
import 'package:net_flow/browser/widgets/compact_browser_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAndroidChannel extends AndroidBrowserChannel {
  _TestAndroidChannel()
      : super(channel: const MethodChannel('net_flow/integration_test'));

  @override
  Future<String?> getInitialUrl() async => null;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('actual Android WebView redirects, link clicks, bookmarks and history',
      (tester) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async => server.close(force: true));
    final origin = 'http://127.0.0.1:${server.port}';
    server.listen((request) async {
      if (request.uri.path == '/google') {
        await request.response.redirect(
          Uri.parse('$origin/www'), status: HttpStatus.found,
        );
        return;
      }
      request.response.headers.contentType = ContentType.html;
      if (request.uri.path == '/www') {
        request.response.write(
          '<!doctype html><html><head><title>Google start</title></head>'
          '<body><a id="article" href="/article">Open article</a></body></html>',
        );
      } else if (request.uri.path == '/article') {
        request.response.write(
          '<!doctype html><html><head><title>Real article</title></head>'
          '<body><h1>Article loaded</h1></body></html>',
        );
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });

    InAppWebViewController? controller;
    await tester.pumpWidget(MaterialApp(
      home: CompactBrowserPage(
        androidChannel: _TestAndroidChannel(),
        initialState: BrowserState(
          currentUrl: '$origin/google',
          isLoading: true,
        ),
        onWebViewReadyForTest: (webViewController) {
          controller = webViewController;
        },
      ),
    ));

    Future<void> waitForUrl(String targetPath) async {
      final deadline = DateTime.now().add(const Duration(seconds: 35));
      String? observed;
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 150));
        final webViewController = controller;
        if (webViewController != null) {
          observed = (await webViewController.getUrl())?.toString();
          if (observed == '$origin$targetPath') {
            // Allow native history updates to reach Flutter callbacks.
            await tester.pump(const Duration(milliseconds: 400));
            return;
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      fail('WebView did not reach $targetPath; got $observed');
    }

    await waitForUrl('/www');
    expect(controller, isNotNull);

    // This is an actual HTML link click inside Android WebView, not an
    // address-bar navigation or a synthetic Flutter callback.
    await controller!.evaluateJavascript(
      source: "document.getElementById('article').click()",
    );
    await waitForUrl('/article');

    // Native history should turn on the Back button on the Flutter toolbar.
    final historyDeadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(historyDeadline) &&
        (await controller!.canGoBack()) != true) {
      await tester.pump(const Duration(milliseconds: 120));
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
    expect(await controller!.canGoBack(), isTrue);

    await tester.tap(find.byKey(const Key('browser-menu-button')));
    await tester.pumpAndSettle();
    final addressField = tester.widget<TextField>(
      find.byKey(const Key('browser-address-field')),
    );
    expect(addressField.controller!.text, '$origin/article');

    await tester.tap(find.text('שמור'));
    await tester.pumpAndSettle();
    await preferences.reload();
    final bookmarks = jsonDecode(preferences.getString('bookmarks')!)
        as List<dynamic>;
    expect((bookmarks.first as Map<String, dynamic>)['url'],
        '$origin/article');

    await tester.tap(find.byKey(const Key('browser-back-button')));
    await waitForUrl('/www');
    await tester.tap(find.byKey(const Key('browser-forward-button')));
    await waitForUrl('/article');

    // Check that the address menu follows the real page after traversing.
    await tester.tap(find.byKey(const Key('browser-menu-button')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(
        find.byKey(const Key('browser-address-field')),
      ).controller!.text,
      '$origin/article',
    );
  });
}
