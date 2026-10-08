/// Tracks main-frame navigation on a WebView reused between addresses.
///
/// Platform callbacks do not carry request IDs. Keep late events from an older
/// page from overwriting the active URL, title and loading indicator.
class BrowserNavigationGuard {
  BrowserNavigationGuard({String? initialUrl}) : _activeUrl = initialUrl;

  String? _activeUrl;
  String? _pendingRequestedUrl;
  bool _isNavigating = false;
  final Set<String> _supersededHistoryUrls = <String>{};

  void navigateTo(String url) {
    _rememberPreviousUrl(url);
    _activeUrl = url;
    _pendingRequestedUrl = url;
    _isNavigating = true;
  }

  void resetTo(String url) {
    _activeUrl = url;
    _pendingRequestedUrl = null;
    _isNavigating = false;
    _supersededHistoryUrls.clear();
  }

  bool acceptLoadStart(String url) {
    if (_pendingRequestedUrl != null &&
        !_sameUrl(_pendingRequestedUrl!, url)) {
      return false;
    }
    _rememberPreviousUrl(url);
    _pendingRequestedUrl = null;
    _activeUrl = url;
    _isNavigating = true;
    // A genuine redirect can load the earlier address again.
    _supersededHistoryUrls.removeWhere((old) => _sameUrl(old, url));
    return true;
  }

  bool acceptVisitedUrl(String url) {
    if (_pendingRequestedUrl != null &&
        !_sameUrl(_pendingRequestedUrl!, url)) {
      return false;
    }
    // A previous page may emit history callbacks after the new load started.
    if (_isNavigating &&
        _supersededHistoryUrls.any((old) => _sameUrl(old, url))) {
      return false;
    }
    _activeUrl = url;
    return true;
  }

  bool acceptLoadStop(String url) {
    if (!isCurrentUrl(url)) {
      return false;
    }
    _pendingRequestedUrl = null;
    _isNavigating = false;
    _supersededHistoryUrls.clear();
    return true;
  }

  bool isCurrentUrl(String url) =>
      _activeUrl != null && _sameUrl(_activeUrl!, url);

  /// A title event contains no URL; refresh the title only after load-stop.
  bool get canRefreshTitle => !_isNavigating;

  void cancelPending() {
    _pendingRequestedUrl = null;
    _isNavigating = false;
    _supersededHistoryUrls.clear();
  }

  void _rememberPreviousUrl(String nextUrl) {
    final previous = _activeUrl;
    if (previous != null && !_sameUrl(previous, nextUrl)) {
      _supersededHistoryUrls.add(previous);
    }
  }

  /// Chromium may add '/' to bare origins and omit default 80/443 ports.
  static bool _sameUrl(String first, String second) {
    if (first == second) {
      return true;
    }
    final a = Uri.tryParse(first);
    final b = Uri.tryParse(second);
    if (a == null ||
        b == null ||
        (a.scheme != 'http' && a.scheme != 'https') ||
        a.scheme != b.scheme ||
        a.host.isEmpty ||
        b.host.isEmpty) {
      return false;
    }

    String path(Uri url) => url.path.isEmpty ? '/' : url.path;

    return a.host == b.host &&
        a.port == b.port &&
        a.userInfo == b.userInfo &&
        path(a) == path(b) &&
        a.query == b.query &&
        a.fragment == b.fragment;
  }
}
