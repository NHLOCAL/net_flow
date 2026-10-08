/// Tracks the URL of the active main-frame navigation on a reused WebView.
///
/// WebView callbacks have no request ID. Explicit address-bar navigations set
/// an expected URL so callbacks from the previous page cannot replace the
/// current URL or mark the newer request as finished.
class BrowserNavigationGuard {
  BrowserNavigationGuard({String? initialUrl}) : _activeUrl = initialUrl;

  String? _activeUrl;
  String? _pendingRequestedUrl;

  /// Start a user-requested navigation before dispatching it to the WebView.
  void navigateTo(String url) {
    _activeUrl = url;
    _pendingRequestedUrl = url;
  }

  /// Return to the native home screen; callbacks from the old view are stale.
  void resetTo(String url) {
    _activeUrl = url;
    _pendingRequestedUrl = null;
  }

  /// Accept the requested page's first load; subsequent redirects are valid.
  bool acceptLoadStart(String url) {
    if (_pendingRequestedUrl != null && _pendingRequestedUrl != url) {
      return false;
    }
    _pendingRequestedUrl = null;
    _activeUrl = url;
    return true;
  }

  /// Ignore history callbacks from the old page before the new load starts.
  bool acceptVisitedUrl(String url) {
    if (_pendingRequestedUrl != null && _pendingRequestedUrl != url) {
      return false;
    }
    _activeUrl = url;
    return true;
  }

  /// Only the currently displayed URL can finish its loading indicator.
  bool acceptLoadStop(String url) {
    if (_activeUrl != url) {
      return false;
    }
    _pendingRequestedUrl = null;
    return true;
  }

  bool isCurrentUrl(String url) => _activeUrl == url;

  /// Used after an explicit stop or a main-frame network failure.
  void cancelPending() {
    _pendingRequestedUrl = null;
  }
}
