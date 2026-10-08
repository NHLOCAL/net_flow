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
