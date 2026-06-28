import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/bookmark.dart';
import '../models/browser_error.dart';
import '../models/browser_settings.dart';
import '../models/browser_state.dart';
import '../models/site_permission_decision.dart';
import '../services/android_browser_channel.dart';
import '../services/bookmark_store.dart';
import '../services/download_service.dart';
import '../services/netfree_browser_policy.dart';
import '../services/settings_store.dart';
import '../services/site_permission_store.dart';
import '../services/url_resolver.dart';
import 'browser_error_view.dart';
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
  SitePermissionStore? _permissionStore;

  late BrowserState _state;
  BrowserSettings _settings = const BrowserSettings.defaults();
  List<Bookmark> _bookmarks = <Bookmark>[];
  String? _pendingInitialUrl;
  int _webViewSeed = 0;
  Timer? _loadTimeoutTimer;
  final NetfreeBrowserPolicy _netfreePolicy = const NetfreeBrowserPolicy();

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _androidChannel = widget.androidChannel ?? AndroidBrowserChannel();
    _androidChannel.setOpenUrlHandler(_openIncomingUrl);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _loadTimeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final bookmarkStore = BookmarkStore(preferences);
    final settingsStore = SettingsStore(preferences);
    final permissionStore = SitePermissionStore(preferences);

    final initialUrl = await _safeGetInitialUrl();
    if (!mounted) {
      return;
    }

    setState(() {
      _bookmarkStore = bookmarkStore;
      _permissionStore = permissionStore;
      _bookmarks = bookmarkStore.load();
      _settings = settingsStore.load();
      _pendingInitialUrl = initialUrl;
    });

    if (initialUrl != null && initialUrl.isNotEmpty) {
      await _loadUrl(initialUrl);
    }
  }

  Future<String?> _safeGetInitialUrl() async {
    try {
      return _androidChannel.getInitialUrl();
    } catch (_) {
      return null;
    }
  }

  Future<void> _openIncomingUrl(String url) async {
    await _loadUrl(url);
  }

  Future<void> _loadUrl(String input) async {
    final url = BrowserUrlResolver(settings: _settings).resolve(input);
    if (_isHomeUrl(url)) {
      await _showHome();
      return;
    }

    await _detachWebView();
    if (!mounted) {
      return;
    }
    setState(() {
      _pendingInitialUrl = url;
      _webViewSeed++;
      _state = _state.copyWith(
        currentUrl: url,
        isLoading: true,
        progress: 0,
        clearError: true,
      );
    });
    _startLoadTimeout(url);
  }

  Future<void> _showHome() async {
    _cancelLoadTimeout();
    await _detachWebView();
    if (!mounted) {
      return;
    }
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
        clearError: true,
      );
    });
  }

  Future<void> _detachWebView() async {
    final controller = _webViewController;
    _webViewController = null;
    if (controller == null) {
      return;
    }

    try {
      await controller.stopLoading();
    } catch (_) {
      // The controller can already be detached when an error view replaced it.
    }
  }

  void _startLoadTimeout(String url) {
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = Timer(const Duration(seconds: 12), () async {
      if (!mounted || !_state.isLoading || _state.currentUrl != url) {
        return;
      }
      await _webViewController?.stopLoading();
      if (!mounted) {
        return;
      }
      setState(() {
        _state = _state.copyWith(
          isLoading: false,
          progress: 0,
          error: BrowserError.timeout(url: url),
        );
      });
    });
  }

  void _cancelLoadTimeout() {
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = null;
  }

  Future<void> _showBlankPageErrorIfNeeded(String url) async {
    if (_isHomeUrl(url)) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 800));
    final controller = _webViewController;
    if (!mounted || controller == null || _state.error != null) {
      return;
    }

    final currentUrl = (await controller.getUrl())?.toString();
    if (!mounted || currentUrl != url) {
      return;
    }

    try {
      final result = await controller.evaluateJavascript(
        source: '''
          (() => {
            const body = document.body;
            if (!body) return 0;
            return (body.innerText || '').trim().length +
              (body.querySelectorAll('img, video, canvas, iframe').length * 10);
          })();
        ''',
      );
      final contentScore = int.tryParse(result?.toString() ?? '') ?? 0;
      if (!mounted || contentScore > 0) {
        return;
      }
    } catch (_) {
      return;
    }

    setState(() {
      _state = _state.copyWith(
        isLoading: false,
        progress: 0,
        error: BrowserError.blank(url: url),
      );
    });
  }

  Future<void> _refreshNavigationState() async {
    final controller = _webViewController;
    if (controller == null || !mounted) {
      return;
    }

    final title = await controller.getTitle();
    final url = await controller.getUrl();
    final canGoBack = await controller.canGoBack();
    final canGoForward = await controller.canGoForward();
    if (!mounted) {
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
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);
    final opened = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() {
        _state = _state.copyWith(error: BrowserError.externalApp(url: url));
      });
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
    final error = _state.error;
    if (error != null) {
      await _loadUrl(error.url);
      return;
    }
    final controller = _webViewController;
    if (controller != null) {
      await controller.reload();
      return;
    }
    if (_state.currentUrl.isNotEmpty && !_isHomeUrl(_state.currentUrl)) {
      await _loadUrl(_state.currentUrl);
    }
  }

  Future<void> _stopLoading() async {
    _cancelLoadTimeout();
    await _webViewController?.stopLoading();
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
    return InAppWebView(
      key: ValueKey('browser-webview-$_webViewSeed'),
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
      onWebViewCreated: (controller) async {
        _webViewController = controller;
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
      onLoadStart: (_, url) {
        final loadingUrl = url?.toString() ?? _state.currentUrl;
        _startLoadTimeout(loadingUrl);
        setState(() {
          _pendingInitialUrl = null;
          _state = _state.copyWith(
            currentUrl: loadingUrl,
            isLoading: true,
            progress: 0,
            clearError: true,
          );
        });
      },
      onProgressChanged: (_, progress) {
        setState(() {
          _state = _state.copyWith(progress: progress / 100);
        });
      },
      onTitleChanged: (_, title) {
        setState(() {
          _state = _state.copyWith(title: title ?? 'Net Flow');
        });
      },
      onLoadStop: (_, url) async {
        _cancelLoadTimeout();
        final stoppedUrl = url?.toString() ?? _state.currentUrl;
        setState(() {
          _pendingInitialUrl = null;
          _state = _state.copyWith(
            currentUrl: stoppedUrl,
            isLoading: false,
            progress: 1,
          );
        });
        await _refreshNavigationState();
        await _showBlankPageErrorIfNeeded(stoppedUrl);
      },
      onReceivedError: (_, request, error) {
        if (request.isForMainFrame != true) {
          return;
        }
        _cancelLoadTimeout();
        setState(() {
          _state = _state.copyWith(
            isLoading: false,
            error: BrowserError.fromWebViewDescription(
              url: request.url.toString(),
              description: error.description,
            ),
          );
        });
      },
      onReceivedHttpError: (_, request, response) {
        if (request.isForMainFrame != true) {
          return;
        }
        _cancelLoadTimeout();
        final statusCode = response.statusCode ?? 0;
        if (statusCode >= 400) {
          setState(() {
            _state = _state.copyWith(
              isLoading: false,
              error: BrowserError.fromHttpStatus(
                url: request.url.toString(),
                statusCode: statusCode,
              ),
            );
          });
        }
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
    return url == _settings.homeUrl || url == 'about:blank';
  }

  @override
  Widget build(BuildContext context) {
    final showHome = _state.error == null && _isHomeUrl(_state.currentUrl);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: _state.error != null
                ? BrowserErrorView(
                    error: _state.error!,
                    onRetry: () => _loadUrl(_state.error!.url),
                    onOpenExternally: () => _openExternal(_state.error!.url),
                  )
                : showHome
                    ? BrowserHomePage(onNavigate: _loadUrl)
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
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _BottomBarButton(
                  key: const Key('browser-home-button'),
                  tooltip: 'בית',
                  icon: Icons.home_outlined,
                  onPressed: onHome,
                ),
                _BottomBarButton(
                  key: const Key('browser-reload-button'),
                  tooltip: state.isLoading ? 'עצור' : 'רענן',
                  icon: state.isLoading ? Icons.close : Icons.refresh,
                  onPressed: state.isLoading ? onStop : onReload,
                ),
                _BottomBarButton(
                  key: const Key('browser-forward-button'),
                  tooltip: 'קדימה',
                  icon: Icons.arrow_back,
                  onPressed: onForward,
                ),
                _BottomBarButton(
                  key: const Key('browser-back-button'),
                  tooltip: 'חזרה',
                  icon: Icons.arrow_forward,
                  onPressed: onBack,
                ),
                _BottomBarButton(
                  key: const Key('browser-menu-button'),
                  tooltip: 'אפשרויות נוספות',
                  icon: Icons.more_horiz,
                  onPressed: onMenu,
                ),
              ],
            ),
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
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 40),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
