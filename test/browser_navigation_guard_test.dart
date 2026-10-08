import 'package:flutter_test/flutter_test.dart';
import 'package:net_flow/browser/services/browser_navigation_guard.dart';

void main() {
  test('a late stop of A cannot complete navigation B', () {
    final guard = BrowserNavigationGuard(initialUrl: 'https://a.test/');
    guard.navigateTo('https://b.test/');

    expect(guard.acceptLoadStop('https://a.test/'), isFalse);
    expect(guard.isCurrentUrl('https://b.test/'), isTrue);
    expect(guard.acceptLoadStart('https://b.test/'), isTrue);
    expect(guard.acceptLoadStop('https://a.test/'), isFalse);
    expect(guard.acceptLoadStop('https://b.test/'), isTrue);
  });

  test('late load-start and history events cannot undo the new request', () {
    final guard = BrowserNavigationGuard(initialUrl: 'https://a.test/');
    guard.navigateTo('https://b.test/');

    expect(guard.acceptLoadStart('https://a.test/'), isFalse);
    expect(guard.acceptVisitedUrl('https://a.test/'), isFalse);
    expect(guard.isCurrentUrl('https://b.test/'), isTrue);
    expect(guard.acceptLoadStart('https://b.test/'), isTrue);
    expect(guard.acceptLoadStop('https://b.test/'), isTrue);
  });

  test('repeated navigations reject a superseded intermediate load', () {
    final guard = BrowserNavigationGuard();
    guard.navigateTo('https://a.test/');
    guard.navigateTo('https://b.test/');
    guard.navigateTo('https://c.test/');

    expect(guard.acceptLoadStart('https://b.test/'), isFalse);
    expect(guard.acceptLoadStop('https://b.test/'), isFalse);
    expect(guard.acceptLoadStart('https://c.test/'), isTrue);
    expect(guard.acceptLoadStop('https://c.test/'), isTrue);
  });

  test('regular navigation and redirects remain supported', () {
    final guard = BrowserNavigationGuard(initialUrl: 'https://a.test/');

    expect(guard.acceptLoadStart('https://b.test/'), isTrue);
    expect(guard.acceptLoadStart('https://c.test/redirect'), isTrue);
    expect(guard.acceptVisitedUrl('https://c.test/redirect'), isTrue);
    expect(guard.acceptLoadStop('https://b.test/'), isFalse);
    expect(guard.acceptLoadStop('https://c.test/redirect'), isTrue);
  });

  test('WebView normalization of an origin does not lose its load', () {
    final guard = BrowserNavigationGuard();
    guard.navigateTo('https://example.com');

    expect(guard.acceptLoadStart('https://example.com/'), isTrue);
    expect(guard.isCurrentUrl('https://example.com'), isTrue);
    expect(guard.acceptLoadStop('https://example.com/'), isTrue);
  });

  test('different paths and query strings remain distinct loads', () {
    final guard = BrowserNavigationGuard();
    guard.navigateTo('https://example.com/a?q=one');

    expect(guard.acceptLoadStop('https://example.com/a?q=two'), isFalse);
    expect(guard.acceptLoadStop('https://example.com/b?q=one'), isFalse);
    expect(guard.acceptLoadStart('https://example.com/a?q=one'), isTrue);
    expect(guard.acceptLoadStop('https://example.com/a?q=one'), isTrue);
  });

  test('old history stays rejected after the newer page starts', () {
    final guard = BrowserNavigationGuard(initialUrl: 'https://a.test/');
    guard.navigateTo('https://b.test/');
    expect(guard.acceptLoadStart('https://b.test/'), isTrue);

    expect(guard.acceptVisitedUrl('https://a.test/'), isFalse);
    expect(guard.isCurrentUrl('https://b.test/'), isTrue);
    expect(guard.acceptLoadStop('https://a.test/'), isFalse);
    expect(guard.acceptLoadStop('https://b.test/'), isTrue);
  });

  test('superseded history is rejected across redirects', () {
    final guard = BrowserNavigationGuard(initialUrl: 'https://a.test/');
    guard.navigateTo('https://b.test/');
    expect(guard.acceptLoadStart('https://b.test/'), isTrue);
    expect(guard.acceptLoadStart('https://c.test/'), isTrue);

    expect(guard.acceptVisitedUrl('https://b.test/'), isFalse);
    expect(guard.acceptVisitedUrl('https://a.test/'), isFalse);
    expect(guard.isCurrentUrl('https://c.test/'), isTrue);
    expect(guard.acceptLoadStop('https://c.test/'), isTrue);
  });

  test('genuine redirect back to the old URL remains possible', () {
    final guard = BrowserNavigationGuard(initialUrl: 'https://a.test/');
    guard.navigateTo('https://b.test/');
    expect(guard.acceptLoadStart('https://b.test/'), isTrue);
    expect(guard.acceptLoadStart('https://a.test/'), isFalse);
    expect(guard.acceptVerifiedLoadStart('https://a.test/'), isTrue);
    expect(guard.acceptVisitedUrl('https://a.test/'), isTrue);
    expect(guard.acceptLoadStop('https://a.test/'), isTrue);
  });

  test('explicit default HTTPS and HTTP ports are canonicalized', () {
    final guard = BrowserNavigationGuard();
    guard.navigateTo('https://example.com:443');
    expect(guard.acceptLoadStart('https://example.com/'), isTrue);
    expect(guard.acceptLoadStop('https://example.com/'), isTrue);

    guard.navigateTo('http://example.com:80');
    expect(guard.acceptLoadStart('http://example.com/'), isTrue);
    expect(guard.acceptLoadStop('http://example.com/'), isTrue);
  });

  test('nondefault HTTPS ports stay distinct', () {
    final guard = BrowserNavigationGuard();
    guard.navigateTo('https://example.com:8443/');
    expect(guard.acceptLoadStart('https://example.com/'), isFalse);
    expect(guard.acceptLoadStop('https://example.com/'), isFalse);
    expect(guard.acceptLoadStart('https://example.com:8443/'), isTrue);
  });

  test('title refresh is disabled while the new page loads', () {
    final guard = BrowserNavigationGuard(initialUrl: 'https://a.test/');
    expect(guard.canRefreshTitle, isTrue);
    guard.navigateTo('https://b.test/');
    expect(guard.canRefreshTitle, isFalse);
    expect(guard.acceptLoadStart('https://b.test/'), isTrue);
    expect(guard.canRefreshTitle, isFalse);
    expect(guard.acceptLoadStop('https://b.test/'), isTrue);
    expect(guard.canRefreshTitle, isTrue);
  });

  test('late load-start from A stays blocked after B starts', () {
    final guard = BrowserNavigationGuard(initialUrl: 'https://a.test/');
    guard.navigateTo('https://b.test/');
    expect(guard.acceptLoadStart('https://b.test/'), isTrue);

    expect(guard.acceptLoadStart('https://a.test/'), isFalse);
    expect(guard.isCurrentUrl('https://b.test/'), isTrue);
    expect(guard.acceptLoadStop('https://b.test/'), isTrue);
  });

  test('stale history remains rejected after stop or failure', () {
    final guard = BrowserNavigationGuard(initialUrl: 'https://a.test/');
    guard.navigateTo('https://b.test/');
    expect(guard.acceptLoadStart('https://b.test/'), isTrue);
    guard.cancelPending();

    expect(guard.acceptVisitedUrl('https://a.test/'), isFalse);
    expect(guard.acceptLoadStart('https://a.test/'), isFalse);
    expect(guard.isCurrentUrl('https://b.test/'), isTrue);
    expect(guard.canRefreshTitle, isTrue);
  });

  test('stale history remains rejected even after B finishes', () {
    final guard = BrowserNavigationGuard(initialUrl: 'https://a.test/');
    guard.navigateTo('https://b.test/');
    expect(guard.acceptLoadStart('https://b.test/'), isTrue);
    expect(guard.acceptLoadStop('https://b.test/'), isTrue);

    expect(guard.acceptVisitedUrl('https://a.test/'), isFalse);
    expect(guard.isCurrentUrl('https://b.test/'), isTrue);
  });

  test('verified WebView redirect can revisit a superseded URL', () {
    final guard = BrowserNavigationGuard(initialUrl: 'https://a.test/');
    guard.navigateTo('https://b.test/');
    expect(guard.acceptLoadStart('https://b.test/'), isTrue);
    expect(guard.acceptLoadStart('https://a.test/'), isFalse);
    expect(guard.acceptVerifiedLoadStart('https://a.test/'), isTrue);
    expect(guard.acceptLoadStop('https://a.test/'), isTrue);
  });

  test('verified WebView history can return to a prior page', () {
    final guard = BrowserNavigationGuard(initialUrl: 'https://a.test/');
    guard.navigateTo('https://b.test/');
    expect(guard.acceptLoadStart('https://b.test/'), isTrue);
    expect(guard.acceptLoadStop('https://b.test/'), isTrue);
    expect(guard.acceptVisitedUrl('https://a.test/'), isFalse);
    expect(guard.acceptVerifiedVisitedUrl('https://a.test/'), isTrue);
    expect(guard.isCurrentUrl('https://a.test/'), isTrue);
  });

  test('verified callbacks cannot supersede a newer explicit request', () {
    final guard = BrowserNavigationGuard(initialUrl: 'https://a.test/');
    guard.navigateTo('https://b.test/');
    expect(guard.acceptLoadStart('https://b.test/'), isTrue);
    guard.navigateTo('https://c.test/');

    expect(guard.acceptVerifiedLoadStart('https://a.test/'), isFalse);
    expect(guard.acceptVerifiedVisitedUrl('https://a.test/'), isFalse);
    expect(guard.isCurrentUrl('https://c.test/'), isTrue);
  });

  test('reset and cancellation do not leave a pending URL', () {
    final guard = BrowserNavigationGuard(initialUrl: 'https://a.test/');
    guard.navigateTo('https://b.test/');
    guard.cancelPending();
    expect(guard.acceptLoadStart('https://c.test/'), isTrue);

    guard.navigateTo('https://d.test/');
    guard.resetTo('netflow://home');
    expect(guard.acceptLoadStop('https://d.test/'), isFalse);
    expect(guard.isCurrentUrl('netflow://home'), isTrue);
  });
}
