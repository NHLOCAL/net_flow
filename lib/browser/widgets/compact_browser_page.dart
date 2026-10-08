import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/bookmark.dart';
import '../models/browser_settings.dart';
import '../models/browser_state.dart';
import '../models/site_permission_decision.dart';
import '../services/android_browser_channel.dart';
import '../services/bookmark_store.dart';
import '../services/download_service.dart';
import '../services/netfree_browser_policy.dart';
import '../services/search_history_store.dart';
import '../services/settings_store.dart';
import '../services/site_permission_store.dart';
import '../services/url_resolver.dart';
import 'browser_home_page.dart';
import 'browser_menu_sheet.dart';

class CompactBrowserPage extends StatefulWidget {
  const CompactBrowserPage({
    super.key,
    this.webViewOverride,
    this.androidChannel,
    this.downloadService = const DownloadService(),
    this.initialState = const BrowserState(),
  });

  final Widget? webViewOverride;
  final AndroidBrowserChannel? androidChannel;
  final DownloadService downloadService;
  final BrowserState initialState;

  @override
  State<CompactBrowserPage> createState() => _CompactBrowserPageState();
}

class _CompactBrowserPageState extends State<CompactBrowserPage> {
  late final AndroidBrowserChannel _androidChannel;

  InAppWebViewController? _webViewController;
  BookmarkStore? _bookmarkStore;
  SearchHistoryStore? _searchHistoryStore;
  SitePermissionStore? _permissionStore;

  late BrowserState _state;
  BrowserSettings _settings = const BrowserSettings.defaults();
  List<Bookmark> _bookmarks = <Bookmark>[];
  List<String> _searchHistory = <String>[];
  String? _pendingInitialUrl;
  int _webViewSeed = 0;
  final NetfreeBrowserPolicy _netfreePolicy = const NetfreeBrowserPolicy();

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _androidChannel = widget.androidChannel ?? AndroidBrowserChannel();
    _androidChannel.setOpenUrlHandler(_openIncomingUrl);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final bookmarkStore = BookmarkStore(preferences);
    final searchHistoryStore = SearchHistoryStore(preferences);
    final settingsStore = SettingsStore(preferences);
    final permissionStore = SitePermissionStore(preferences);

    final initialUrl = await _safeGetInitialUrl();
    if (!mounted) {
      return;
    }

    setState(() {
      _bookmarkStore = bookmarkStore;
      _searchHistoryStore = searchHistoryStore;
      _permissionStore = permissionStore;
      _bookmarks = bookmarkStore.load();
      _searchHistory = searchHistoryStore.load();
      _settings = settingsStore.load();
      _pendingInitialUrl = initialUrl;
    });

    if (initialUrl != null && initialUrl.isNotEmpty) {
      await _loadUrl(initialUrl);
    }
  }

  Future<String?> _safeGetInitialUrl() async {
    try {
      return await _androidChannel.getInitialUrl();
    } catch (_) {
      return null;
    }
  }

  Future<void> _openIncomingUrl(String url) async {
    await _loadUrl(url);
  }

  Future<void> _navigateFromHome(String input) async {
    final nextHistory = await _searchHistoryStore?.remember(input.trim());
    if (nextHistory != null && mounted) {
      setState(() => _searchHistory = nextHistory);
    }
    await _loadUrl(input);
  }

  Future<void> _loadUrl(String input) async {
    final url = BrowserUrlResolver(settings: _settings).resolve(input);
    if (_isHomeUrl(url)) {
      await _showHome();
      return;
    }

    // Reuse the current WebView so navigation does not discard page history,
    // cookies, or in-flight site state.
    final controller = _webViewController;
    if (!mounted) {
      return;
    }
    setState(() {
      _pendingInitialUrl = controller == null ? url : null;
      if (controller == null) {
        _webViewSeed++;
      }
      _state = _state.copyWith(
        currentUrl: url,
        title: 'Net Flow',
        isLoading: true,
        progress: 0,
        canGoBack: controller == null ? false : _state.canGoBack,
        canGoForward: controller == null ? false : _state.canGoForward,
      );
    });

    if (controller == null) {
      return;
    }
    try {
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    } catch (_) {
      if (!mounted ||
          _webViewController != controller ||
          _state.currentUrl != url) {
        return;
      }
      // Recover from a disposed platform view without showing a custom error.
      _webViewController = null;
      setState(() {
        _pendingInitialUrl = url;
        _webViewSeed++;
      });
    }
  }

  Future<void> _showHome() async {
    final controller = _webViewController;
    _webViewController = null;
    if (!mounted) {
      return;
    }
    // Show home immediately even if the remote site is still loading.
    setState(() {
      _pendingInitialUrl = null;
      _webViewSeed++;
      _state = _state.copyWith(
        currentUrl: _settings.homeUrl,
        title: 'Net Flow',
        isLoading: false,
        progress: 0,
        canGoBack: false,
        canGoForward: false,
      );
    });

    try {
      await controller?.stopLoading();
    } catch (_) {
      // The old platform WebView may already have been disposed.
    }
  }

  Future<void> _refreshNavigationState() async {
    final controller = _webViewController;
    if (controller == null || !mounted) {
      return;
    }
    final expectedUrl = _state.currentUrl;
    try {
      final title = await controller.getTitle();
      final url = await controller.getUrl();
      final canGoBack = await controller.canGoBack();
      final canGoForward = await controller.canGoForward();
      if (!mounted ||
          _webViewController != controller ||
          _state.currentUrl != expectedUrl) {
        return;
      }

      setState(() {
        _state = _state.copyWith(
          currentUrl: url?.toString() ?? _state.currentUrl,
          title: title?.isNotEmpty == true ? title! : 'Net Flow',
          canGoBack: canGoBack,
          canGoForward: canGoForward,
        );
      });
    } catch (_) {
      // Ignore callbacks from a WebView that was closed during navigation.
    }
  }

  Future<void> _openExternal(String url) async {
    var opened = false;
    try {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Missing or unsupported Android intent handlers are not page errors.
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('אין אפליקציה זמינה לפתיחת הקישור')),
      );
    }
  }

  Future<NavigationActionPolicy> _handleNavigation(
    NavigationAction action,
  ) async {
    final url = action.request.url;
    if (url == null) {
      return NavigationActionPolicy.ALLOW;
    }

    final uri = Uri.tryParse(url.toString());
    if (uri != null && const BrowserUrlResolver().isExternalScheme(uri)) {
      await _openExternal(url.toString());
      return NavigationActionPolicy.CANCEL;
    }

    return NavigationActionPolicy.ALLOW;
  }

  Future<void> _handleDownload(DownloadStartRequest request) async {
    try {
      await widget.downloadService.enqueue(
        url: request.url.toString(),
        fileName: request.suggestedFilename,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ההורדה החלה')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ההורדה נכשלה: $error')),
        );
      }
    }
  }

  Future<PermissionResponse> _handlePermissionRequest(
    PermissionRequest request,
  ) async {
    final resources = _mapResources(request.resources);
    if (resources.isEmpty) {
      return PermissionResponse(
        resources: request.resources,
        action: PermissionResponseAction.DENY,
      );
    }

    final origin = _originFor(request.origin.toString());
    final store = _permissionStore;
    final storedDecisions = store == null
        ? <SitePermissionDecision>[]
        : resources
            .map((resource) => store.get(origin: origin, resource: resource))
            .whereType<SitePermissionDecision>()
            .toList();

    if (storedDecisions.length == resources.length) {
      final allow = storedDecisions.every(
        (decision) => decision.action == SitePermissionAction.allow,
      );
      final osGranted =
          allow ? await _requestAndroidPermissions(resources) : false;
      return PermissionResponse(
        resources: request.resources,
        action: allow && osGranted
            ? PermissionResponseAction.GRANT
            : PermissionResponseAction.DENY,
      );
    }

    final decision = await _askSitePermission(
      origin: origin,
      resource: resources.first,
    );
    if (decision == null) {
      return PermissionResponse(
        resources: request.resources,
        action: PermissionResponseAction.DENY,
      );
    }

    if (decision.persist) {
      for (final resource in resources) {
        await store?.save(SitePermissionDecision(
          origin: origin,
          resource: resource,
          action: decision.action,
          persist: true,
        ));
      }
    }

    final allow = decision.action == SitePermissionAction.allow &&
        await _requestAndroidPermissions(resources);
    return PermissionResponse(
      resources: request.resources,
      action: allow
          ? PermissionResponseAction.GRANT
          : PermissionResponseAction.DENY,
    );
  }

  Future<GeolocationPermissionShowPromptResponse> _handleGeolocation(
    String origin,
  ) async {
    final normalizedOrigin = _originFor(origin);
    final stored = _permissionStore?.get(
      origin: normalizedOrigin,
      resource: SitePermissionResource.geolocation,
    );
    if (stored != null) {
      final allow = stored.action == SitePermissionAction.allow &&
          await _requestAndroidPermissions(
            const <SitePermissionResource>[SitePermissionResource.geolocation],
          );
      return GeolocationPermissionShowPromptResponse(
        origin: origin,
        allow: allow,
        retain: stored.persist,
      );
    }

    final decision = await _askSitePermission(
      origin: normalizedOrigin,
      resource: SitePermissionResource.geolocation,
    );
    if (decision?.persist == true) {
      await _permissionStore?.save(decision!);
    }

    final allow = decision?.action == SitePermissionAction.allow &&
        await _requestAndroidPermissions(
          const <SitePermissionResource>[SitePermissionResource.geolocation],
        );
    return GeolocationPermissionShowPromptResponse(
      origin: origin,
      allow: allow,
      retain: decision?.persist == true,
    );
  }

  Future<SitePermissionDecision?> _askSitePermission({
    required String origin,
    required SitePermissionResource resource,
  }) {
    if (!mounted) {
      return Future<SitePermissionDecision?>.value();
    }

    return showModalBottomSheet<SitePermissionDecision>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'בקשת הרשאה',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('$origin מבקש ${_permissionLabel(resource)}.'),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('אפשר וזכור לאתר הזה'),
                    onPressed: () => Navigator.of(context).pop(
                      SitePermissionDecision(
                        origin: origin,
                        resource: resource,
                        action: SitePermissionAction.allow,
                        persist: true,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('אפשר פעם אחת'),
                    onPressed: () => Navigator.of(context).pop(
                      SitePermissionDecision(
                        origin: origin,
                        resource: resource,
                        action: SitePermissionAction.allow,
                        persist: false,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.block),
                    label: const Text('דחה'),
                    onPressed: () => Navigator.of(context).pop(
                      SitePermissionDecision(
                        origin: origin,
                        resource: resource,
                        action: SitePermissionAction.deny,
                        persist: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _requestAndroidPermissions(
    List<SitePermissionResource> resources,
  ) async {
    final permissions = <Permission>{
      for (final resource in resources) ..._androidPermissionsFor(resource),
    };
    for (final permission in permissions) {
      final status = await permission.request();
      if (!status.isGranted) {
        return false;
      }
    }
    return true;
  }

  Iterable<Permission> _androidPermissionsFor(SitePermissionResource resource) {
    switch (resource) {
      case SitePermissionResource.camera:
        return const <Permission>[Permission.camera];
      case SitePermissionResource.microphone:
        return const <Permission>[Permission.microphone];
      case SitePermissionResource.geolocation:
        return const <Permission>[Permission.locationWhenInUse];
    }
  }

  List<SitePermissionResource> _mapResources(
    List<PermissionResourceType> resources,
  ) {
    final mapped = <SitePermissionResource>{};
    for (final resource in resources) {
      if (resource == PermissionResourceType.CAMERA) {
        mapped.add(SitePermissionResource.camera);
      } else if (resource == PermissionResourceType.MICROPHONE) {
        mapped.add(SitePermissionResource.microphone);
      } else if (resource == PermissionResourceType.CAMERA_AND_MICROPHONE) {
        mapped.addAll(const <SitePermissionResource>[
          SitePermissionResource.camera,
          SitePermissionResource.microphone,
        ]);
      } else if (resource == PermissionResourceType.GEOLOCATION) {
        mapped.add(SitePermissionResource.geolocation);
      }
    }
    return mapped.toList(growable: false);
  }

  String _permissionLabel(SitePermissionResource resource) {
    switch (resource) {
      case SitePermissionResource.camera:
        return 'גישה למצלמה';
      case SitePermissionResource.microphone:
        return 'גישה למיקרופון';
      case SitePermissionResource.geolocation:
        return 'גישה למיקום';
    }
  }

  String _originFor(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
      return url;
    }
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  Future<void> _addBookmark() async {
    final url = _state.currentUrl;
    if (url.isEmpty || _isHomeUrl(url)) {
      return;
    }

    final title = _state.title == 'Net Flow' ? _hostFor(url) : _state.title;
    final bookmark = Bookmark(title: title, url: url);
    final next = <Bookmark>[
      ..._bookmarks.where((item) => item.url != url),
      bookmark,
    ];
    await _bookmarkStore?.save(next);
    if (mounted) {
      setState(() => _bookmarks = next);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('הסימניה "$title" נשמרה')),
      );
    }
  }

  Future<void> _deleteBookmark(Bookmark bookmark) async {
    final next = _bookmarks.where((item) => item.url != bookmark.url).toList();
    await _bookmarkStore?.save(next);
    if (mounted) {
      setState(() => _bookmarks = next);
    }
  }

  String _hostFor(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return url;
    }
    return uri.host.replaceFirst('www.', '');
  }

  Future<void> _showMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return BrowserMenuSheet(
          state: _state,
          bookmarks: _bookmarks,
          onNavigate: _loadUrl,
          onAddBookmark: _addBookmark,
          onOpenBookmark: (bookmark) => _loadUrl(bookmark.url),
          onDeleteBookmark: _deleteBookmark,
          onShowSitePermissions: _showSitePermissions,
        );
      },
    );
  }

  Future<void> _goBack() async {
    await _webViewController?.goBack();
    await _refreshNavigationState();
  }

  Future<void> _goForward() async {
    await _webViewController?.goForward();
    await _refreshNavigationState();
  }

  Future<void> _reloadCurrent() async {
    final controller = _webViewController;
    if (controller != null) {
      try {
        await controller.reload();
        return;
      } catch (_) {
        // Recreate the platform view only if its controller is invalid.
        if (_webViewController == controller) {
          _webViewController = null;
        }
      }
    }
    if (_state.currentUrl.isNotEmpty && !_isHomeUrl(_state.currentUrl)) {
      await _loadUrl(_state.currentUrl);
    }
  }

  Future<void> _stopLoading() async {
    try {
      await _webViewController?.stopLoading();
    } catch (_) {
      // Stopping an already disposed WebView is harmless.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _state = _state.copyWith(isLoading: false, progress: 0);
    });
  }

  Future<void> _showSitePermissions() async {
    final decisions = _permissionStore?.all() ?? <SitePermissionDecision>[];
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'הרשאות אתרים',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (decisions.isEmpty)
                    const Text('אין הרשאות שמורות.')
                  else
                    ...decisions.map(
                      (decision) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(decision.origin),
                        subtitle: Text(_permissionLabel(decision.resource)),
                        trailing: Text(
                          decision.action == SitePermissionAction.allow
                              ? 'מאושר'
                              : 'חסום',
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('נקה הרשאות לאתר הנוכחי'),
                    onPressed: () async {
                      await _permissionStore?.clearForOrigin(
                        _originFor(_state.currentUrl),
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWebView() {
    if (widget.webViewOverride != null) {
      return widget.webViewOverride!;
    }

    final initialUrl = _initialWebViewUrl();
    final viewSeed = _webViewSeed;
    return InAppWebView(
      key: ValueKey('browser-webview-$viewSeed'),
      initialUrlRequest: URLRequest(url: WebUri(initialUrl)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        useShouldOverrideUrlLoading: true,
        useOnDownloadStart: true,
        supportMultipleWindows: true,
        mediaPlaybackRequiresUserGesture: false,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        allowsInlineMediaPlayback: true,
        supportZoom: true,
        builtInZoomControls: true,
        displayZoomControls: false,
        safeBrowsingEnabled: false,
        transparentBackground: false,
        isInspectable: kDebugMode,
      ),
      onWebViewCreated: (controller) {
        if (mounted && _webViewSeed == viewSeed) {
          _webViewController = controller;
        }
      },
      shouldOverrideUrlLoading: (_, action) => _handleNavigation(action),
      onCreateWindow: (controller, action) async {
        final url = action.request.url;
        if (url != null) {
          await controller.loadUrl(urlRequest: URLRequest(url: url));
        }
        return true;
      },
      onReceivedServerTrustAuthRequest: (_, __) async {
        return _netfreePolicy.serverTrustResponse();
      },
      onLoadStart: (controller, url) {
        if (!mounted || _webViewController != controller) {
          return;
        }
        final loadingUrl = url?.toString() ?? _state.currentUrl;
        setState(() {
          _pendingInitialUrl = null;
          _state = _state.copyWith(
            currentUrl: loadingUrl,
            isLoading: true,
            progress: 0,
          );
        });
      },
      onProgressChanged: (controller, progress) {
        if (!mounted || _webViewController != controller) {
          return;
        }
        setState(() {
          _state = _state.copyWith(
            progress: progress / 100,
            isLoading: progress >= 100 ? false : _state.isLoading,
          );
        });
      },
      onTitleChanged: (controller, title) {
        if (!mounted || _webViewController != controller) {
          return;
        }
        setState(() {
          _state = _state.copyWith(title: title ?? 'Net Flow');
        });
      },
      onLoadStop: (controller, url) async {
        if (!mounted || _webViewController != controller) {
          return;
        }
        final stoppedUrl = url?.toString() ?? _state.currentUrl;
        if (stoppedUrl != _state.currentUrl) {
          // A superseded navigation may finish after a newer one has begun.
          return;
        }
        setState(() {
          _pendingInitialUrl = null;
          _state = _state.copyWith(
            currentUrl: stoppedUrl,
            isLoading: false,
            progress: 1,
          );
        });
        await _refreshNavigationState();
      },
      onUpdateVisitedHistory: (controller, url, _) {
        if (!mounted || _webViewController != controller || url == null) {
          return;
        }
        final visitedUrl = url.toString();
        if (visitedUrl != _state.currentUrl) {
          setState(() {
            _state = _state.copyWith(currentUrl: visitedUrl);
          });
        }
        unawaited(_refreshNavigationState());
      },
      onReceivedError: (controller, request, _) {
        // Keep native WebView errors and filtering/interstitial pages visible.
        // Subresource failures and stale navigation failures must not replace
        // the current page or stop a different page's loading indicator.
        if (!mounted ||
            _webViewController != controller ||
            request.isForMainFrame != true ||
            request.url.toString() != _state.currentUrl) {
          return;
        }
        setState(() {
          _state = _state.copyWith(isLoading: false, progress: 0);
        });
      },
      onDownloadStartRequest: (_, request) => _handleDownload(request),
      onPermissionRequest: (_, request) => _handlePermissionRequest(request),
      onGeolocationPermissionsShowPrompt: (_, origin) {
        return _handleGeolocation(origin);
      },
    );
  }

  String _initialWebViewUrl() {
    final pending = _pendingInitialUrl;
    if (pending != null && pending.isNotEmpty && !_isHomeUrl(pending)) {
      return pending;
    }
    if (_state.currentUrl.isNotEmpty && !_isHomeUrl(_state.currentUrl)) {
      return _state.currentUrl;
    }
    return 'about:blank';
  }

  bool _isHomeUrl(String url) {
    return url == _settings.homeUrl;
  }

  @override
  Widget build(BuildContext context) {
    final showHome = _isHomeUrl(_state.currentUrl);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: showHome
                ? BrowserHomePage(
                    onNavigate: _navigateFromHome,
                    recentSearches: _searchHistory,
                    bookmarks: _bookmarks,
                  )
                : _buildWebView(),
          ),
          if (_state.isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  value: _state.progress <= 0 || _state.progress >= 1
                      ? null
                      : _state.progress,
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BrowserBottomBar(
              state: _state,
              onHome: _showHome,
              onReload: _reloadCurrent,
              onStop: _stopLoading,
              onForward: _state.canGoForward ? _goForward : null,
              onBack: _state.canGoBack ? _goBack : null,
              onMenu: _showMenu,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowserBottomBar extends StatelessWidget {
  const _BrowserBottomBar({
    required this.state,
    required this.onHome,
    required this.onReload,
    required this.onStop,
    required this.onForward,
    required this.onBack,
    required this.onMenu,
  });

  final BrowserState state;
  final VoidCallback onHome;
  final VoidCallback onReload;
  final VoidCallback onStop;
  final VoidCallback? onForward;
  final VoidCallback? onBack;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          key: const Key('browser-bottom-bar'),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.94),
            border: Border(
              top: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(
                  child: _BottomBarButton(
                    key: const Key('browser-home-button'),
                    tooltip: 'בית',
                    icon: Icons.home_outlined,
                    onPressed: onHome,
                  ),
                ),
                const _BottomBarSeparator(index: 0),
                Expanded(
                  child: _BottomBarButton(
                    key: const Key('browser-reload-button'),
                    tooltip: state.isLoading ? 'עצור' : 'רענן',
                    icon: state.isLoading ? Icons.close : Icons.refresh,
                    onPressed: state.isLoading ? onStop : onReload,
                  ),
                ),
                const _BottomBarSeparator(index: 1),
                Expanded(
                  child: _BottomBarButton(
                    key: const Key('browser-forward-button'),
                    tooltip: 'קדימה',
                    icon: Icons.arrow_back,
                    onPressed: onForward,
                  ),
                ),
                const _BottomBarSeparator(index: 2),
                Expanded(
                  child: _BottomBarButton(
                    key: const Key('browser-back-button'),
                    tooltip: 'חזרה',
                    icon: Icons.arrow_forward,
                    onPressed: onBack,
                  ),
                ),
                const _BottomBarSeparator(index: 3),
                Expanded(
                  child: _BottomBarButton(
                    key: const Key('browser-menu-button'),
                    tooltip: 'אפשרויות נוספות',
                    icon: Icons.more_horiz,
                    onPressed: onMenu,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBarSeparator extends StatelessWidget {
  const _BottomBarSeparator({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: SizedBox(
        key: Key('browser-bottom-bar-separator-$index'),
        width: 1,
        height: 30,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.outlineVariant.withValues(alpha: 0.88),
          ),
        ),
      ),
    );
  }
}

class _BottomBarButton extends StatelessWidget {
  const _BottomBarButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = onPressed != null;
    final foreground = isEnabled
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.38);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            height: 48,
            child: Center(
              child: Icon(icon, size: 21, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
