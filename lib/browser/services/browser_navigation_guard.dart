/// Tracks main-frame navigation on a WebView reused between addresses.
///
/// Native callbacks do not carry a navigation ID. Suppress callbacks for
/// superseded URLs until the actual WebView URL confirms a deliberate return.
class BrowserNavigationGuard {
  BrowserNavigationGuard({String? initialUrl}) : _activeUrl = initialUrl;

  static const _maxSupersededUrls = 16;

  String? _activeUrl;
  String? _pendingRequestedUrl;
  bool _isNavigating = false;
  final Set<String> _supersededUrls = <String>{};

  void navigateTo(String url) {
    _rememberPreviousUrl(url);
    // An explicit user navigation back to an old address is always valid.
    _forgetSuperseded(url);
    _activeUrl = url;
    _pendingRequestedUrl = url;
    _isNavigating = true;
  }

  void resetTo(String url) {
    _activeUrl = url;
    _pendingRequestedUrl = null;
    _isNavigating = false;
    _supersededUrls.clear();
  }

  bool acceptLoadStart(String url) {
    if (!_matchesPendingRequest(url) || isSupersededUrl(url)) {
      return false;
    }
    _activateStart(url);
    return true;
  }

  /// Call only when controller.getUrl() confirms this is the current page.
  bool acceptVerifiedLoadStart(String url) {
    if (!_matchesPendingRequest(url)) {
      return false;
    }
    _activateStart(url);
    return true;
  }

  bool acceptVisitedUrl(String url) {
    if (!_matchesPendingRequest(url) || isSupersededUrl(url)) {
      return false;
    }
    _activeUrl = url;
    return true;
  }

  /// Call only when controller.getUrl() confirms this history entry is live.
  bool acceptVerifiedVisitedUrl(String url) {
    if (!_matchesPendingRequest(url)) {
      return false;
    }
    _forgetSuperseded(url);
    _activeUrl = url;
    return true;
  }

  bool acceptLoadStop(String url) {
    if (!isCurrentUrl(url)) {
      return false;
    }
    _pendingRequestedUrl = null;
    _isNavigating = false;
    // Do not remove superseded URLs: queued callbacks may arrive even after
    // the new page completed or a user deliberately stopped its loading.
    return true;
  }

  bool isCurrentUrl(String url) =>
      _activeUrl != null && _sameUrl(_activeUrl!, url);

  bool isSupersededUrl(String url) =>
      _supersededUrls.any((old) => _sameUrl(old, url));

  bool get canRefreshTitle => !_isNavigating;

  void cancelPending() {
    _pendingRequestedUrl = null;
    _isNavigating = false;
    // Preserve stale-event protection after stopLoading/main-frame errors.
  }

  void _activateStart(String url) {
    _rememberPreviousUrl(url);
    _forgetSuperseded(url);
    _activeUrl = url;
    _pendingRequestedUrl = null;
    _isNavigating = true;
  }

  bool _matchesPendingRequest(String url) =>
      _pendingRequestedUrl == null ||
      _sameUrl(_pendingRequestedUrl!, url);

  void _rememberPreviousUrl(String nextUrl) {
    final previous = _activeUrl;
    if (previous != null && !_sameUrl(previous, nextUrl)) {
      _supersededUrls.add(previous);
      if (_supersededUrls.length > _maxSupersededUrls) {
        _supersededUrls.remove(_supersededUrls.first);
      }
    }
  }

  void _forgetSuperseded(String url) {
    _supersededUrls.removeWhere((old) => _sameUrl(old, url));
  }

  static bool urlsMatch(String first, String second) => _sameUrl(first, second);

  /// Compare canonical components, including default HTTP(S) ports.
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
