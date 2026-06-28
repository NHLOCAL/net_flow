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
}
