import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class NetfreeBrowserPolicy {
  const NetfreeBrowserPolicy();

  bool get ignoreDownloadSsl => true;

  ServerTrustAuthResponseAction get serverTrustAction =>
      ServerTrustAuthResponseAction.PROCEED;

  ServerTrustAuthResponse serverTrustResponse() {
    return ServerTrustAuthResponse(action: serverTrustAction);
  }
}
