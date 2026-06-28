import 'package:flutter_test/flutter_test.dart';
import 'package:net_flow/browser/services/url_resolver.dart';

void main() {
  group('BrowserUrlResolver', () {
    const resolver = BrowserUrlResolver();

    test('keeps absolute https URLs unchanged', () {
      expect(
        resolver.resolve('https://example.com/path?q=1'),
        'https://example.com/path?q=1',
      );
    });

    test('adds https scheme to plain domains', () {
      expect(resolver.resolve('netfree.link'), 'https://netfree.link');
    });

    test('keeps paths on plain domains', () {
      expect(
        resolver.resolve('example.com/path?q=1'),
        'https://example.com/path?q=1',
      );
    });

    test('turns free text with punctuation into a Google search URL', () {
      expect(
        resolver.resolve('hello.world test'),
        'https://www.google.com/search?q=hello.world%20test',
      );
      expect(
        resolver.resolve('example'),
        'https://www.google.com/search?q=example',
      );
      expect(
        resolver.resolve('bad_domain.com'),
        'https://www.google.com/search?q=bad_domain.com',
      );
    });

    test('turns Hebrew text into a Google search URL', () {
      expect(
        resolver.resolve('בדיקת נטפרי'),
        'https://www.google.com/search?q=%D7%91%D7%93%D7%99%D7%A7%D7%AA%20%D7%A0%D7%98%D7%A4%D7%A8%D7%99',
      );
    });

    test('identifies external schemes', () {
      expect(resolver.isExternalScheme(Uri.parse('mailto:test@example.com')),
          isTrue);
      expect(resolver.isExternalScheme(Uri.parse('tel:1234')), isTrue);
      expect(
          resolver.isExternalScheme(Uri.parse('https://example.com')), isFalse);
    });
  });
}
