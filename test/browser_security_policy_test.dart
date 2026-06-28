import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:net_flow/browser/services/netfree_browser_policy.dart';

void main() {
  test('continues WebView loading when Android reports a server trust issue', () {
    const policy = NetfreeBrowserPolicy();

    expect(
      policy.serverTrustAction,
      ServerTrustAuthResponseAction.PROCEED,
    );
  });

  test('downloads ignore SSL failures for Netfree compatibility', () {
    const policy = NetfreeBrowserPolicy();

    expect(policy.ignoreDownloadSsl, isTrue);
  });
}
