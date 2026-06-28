import 'package:flutter_test/flutter_test.dart';
import 'package:net_flow/browser/models/browser_error.dart';

void main() {
  test('maps HTTP 418 to Netfree friendly copy', () {
    final error = BrowserError.fromHttpStatus(
      url: 'https://example.com',
      statusCode: 418,
    );

    expect(error.kind, BrowserErrorKind.netfreeBlocked);
    expect(error.title, contains('נטפרי'));
  });

  test('maps SSL failures to certificate guidance', () {
    final error = BrowserError.fromWebViewDescription(
      url: 'https://example.com',
      description: 'SSL handshake failed',
    );

    expect(error.kind, BrowserErrorKind.ssl);
    expect(error.message, contains('תעודה'));
  });

  test('maps stalled loads to network guidance', () {
    final error = BrowserError.timeout(url: 'https://example.com');

    expect(error.kind, BrowserErrorKind.load);
    expect(error.title, contains('לא הסתיימה'));
    expect(error.message, contains('רשת'));
  });

  test('maps blank loads to network or filtering guidance', () {
    final error = BrowserError.blank(url: 'https://example.com');

    expect(error.kind, BrowserErrorKind.load);
    expect(error.title, contains('ריק'));
    expect(error.message, contains('נטפרי'));
  });
}
