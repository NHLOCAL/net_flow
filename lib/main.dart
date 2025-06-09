import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  runApp(MyBrowserApp());
}

class MyBrowserApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Mini Browser',
      locale: Locale('he'),
      supportedLocales: [
        Locale('he'),
      ],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: BrowserHomePage(),
    );
  }
}

class BrowserHomePage extends StatefulWidget {
  @override
  _BrowserHomePageState createState() => _BrowserHomePageState();
}

class _BrowserHomePageState extends State<BrowserHomePage> {
  late InAppWebViewController _webViewController;
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool isLoading = true;
  bool showBars = true;
  bool _isEditingUrl = false; // *** משתנה חדש לשליטה במצב הסרגל העליון ***
  List<Map<String, String>> bookmarks = [];
  double lastScrollPosition = 0;
  bool _isAnimatingBars = false;
  static const _scrollThreshold = 15.0;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();

    _urlController.addListener(() => setState(() {}));

    // מאזין למצב הפוקוס כדי לצאת ממצב עריכה
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isEditingUrl) {
        setState(() {
          _isEditingUrl = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool isValidUrl(String input) {
    // ... (no changes here)
    final RegExp urlRegExp = RegExp(
      r'^(https?:\/\/)?'
      r'((([a-zA-Z0-9\-]+\.)+[a-zA-Z]{2,}))'
      r'(\/[^\s]*)?$',
      caseSensitive: false,
    );
    return urlRegExp.hasMatch(input);
  }

  void _navigateToUrl() {
    String input = _urlController.text.trim();
    String url;

    if (input.isEmpty) return;

    if (isValidUrl(input)) {
      if (input.startsWith('http://') || input.startsWith('https://')) {
        url = input;
      } else {
        url = 'https://$input';
      }
    } else {
      String query = Uri.encodeComponent(input);
      url = 'https://www.google.com/search?q=$query';
    }

    _webViewController.loadUrl(
      urlRequest: URLRequest(url: WebUri(url)),
    );

    // יציאה ממצב עריכה לאחר ניווט
    _focusNode.unfocus();
    setState(() {
      _isEditingUrl = false;
    });
  }

  Future<void> _loadBookmarks() async {
    // ... (no changes here)
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? bookmarksString = prefs.getString('bookmarks');
    if (bookmarksString != null) {
      List<dynamic> bookmarksJson = jsonDecode(bookmarksString);
      setState(() {
        bookmarks = bookmarksJson
            .map((item) => Map<String, String>.from(item))
            .toList();
      });
    }
  }

  Future<void> _saveBookmarks() async {
    // ... (no changes here)
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String bookmarksString = jsonEncode(bookmarks);
    await prefs.setString('bookmarks', bookmarksString);
  }

  void _addBookmark() {
    String url = _urlController.text;
    if (url.isEmpty || url == 'about:blank') return;

    showDialog(
      context: context,
      builder: (context) {
        TextEditingController nameController =
            TextEditingController(text: _getDomain(url));
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            // *** עיצוב משופר ל-Dialog ***
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0)),
            icon: Icon(Icons.bookmark_add_outlined,
                color: Theme.of(context).colorScheme.primary, size: 32),
            title: Text('הוספת סימניה'),
            content: TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'שם הסימניה',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0)),
              ),
              textDirection: TextDirection.rtl,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('ביטול'),
              ),
              FilledButton(
                onPressed: () {
                  String name = nameController.text.trim();
                  if (name.isEmpty) return;

                  setState(() {
                    bookmarks.add({'name': name, 'url': url});
                    _saveBookmarks();
                  });

                  Navigator.of(context).pop();

                  // משוב למשתמש
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("הסימניה '$name' נשמרה"),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
                child: Text('שמור'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getDomain(String url) {
    if (url.isEmpty || url == 'about:blank') return 'דף חדש';
    try {
      Uri uri = Uri.parse(url);
      return uri.host.isNotEmpty ? uri.host.replaceAll('www.', '') : url;
    } catch (e) {
      return url;
    }
  }

  String _getFormattedUrlForDisplay() {
    String url = _urlController.text;
    if (url.isEmpty || url == 'about:blank') return 'חיפוש או כתובת אתר';
    return _getDomain(url);
  }

  void _openBookmarks() {
    // ... (no changes here)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookmarksPage(
          bookmarks: bookmarks,
          onSelect: (bookmark) {
            _webViewController.loadUrl(
              urlRequest: URLRequest(url: WebUri(bookmark['url']!)),
            );
            Navigator.pop(context);
          },
          onDelete: (bookmark) {
            setState(() {
              bookmarks.remove(bookmark);
              _saveBookmarks();
            });
          },
        ),
      ),
    );
  }

  void _goHome() {
    _webViewController.loadUrl(
        urlRequest: URLRequest(url: WebUri('about:blank')));
  }

  void _setBarsVisibility(bool visible) {
    // ... (no changes here)
    if (showBars == visible || _isAnimatingBars) return;

    setState(() {
      _isAnimatingBars = true;
      showBars = visible;
    });

    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _isAnimatingBars = false;
        });
      }
    });
  }

  // *** ווידג'ט חדש לבניית הסרגל העליון הדינאמי ***
  Widget _buildUrlBar() {
    return GestureDetector(
      onTap: () {
        if (!_isEditingUrl) {
          setState(() {
            _isEditingUrl = true;
            _urlController.selection = TextSelection(
                baseOffset: 0, extentOffset: _urlController.text.length);
            _focusNode.requestFocus();
          });
        }
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // מצב תצוגה
            AnimatedOpacity(
              opacity: _isEditingUrl ? 0.0 : 1.0,
              duration: Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: _isEditingUrl,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_urlController.text.startsWith('https://'))
                      Icon(Icons.lock, size: 16, color: Colors.green.shade700),
                    if (_urlController.text.isNotEmpty) SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _getFormattedUrlForDisplay(),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // מצב עריכה
            AnimatedOpacity(
              opacity: _isEditingUrl ? 1.0 : 0.0,
              duration: Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_isEditingUrl,
                child: TextField(
                  controller: _urlController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'חיפוש או כתובת אתר',
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    suffixIcon: _urlController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () => _urlController.clear(),
                          )
                        : null,
                  ),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (value) => _navigateToUrl(),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: showBars
          ? AppBar(
              // *** עיצוב AppBar חדש ***
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              title: _buildUrlBar(),
              actions: [
                IconButton(
                  icon: Icon(Icons.refresh,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  onPressed: () => _webViewController.reload(),
                  tooltip: 'רענן',
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri('about:blank')),
            onWebViewCreated: (controller) => _webViewController = controller,
            onLoadStart: (controller, url) {
              setState(() {
                isLoading = true;
                _urlController.text = url?.toString() ?? '';
              });
            },
            onLoadStop: (controller, url) {
              setState(() {
                isLoading = false;
                if (url?.toString() == 'about:blank') {
                  _urlController.clear();
                } else {
                  _urlController.text = url?.toString() ?? '';
                }
                _setBarsVisibility(true);
              });
            },
            onReceivedError: (controller, request, error) {
              // ... (no changes here)
              setState(() => isLoading = false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('הטעינה נכשלה: ${error.description}')),
                );
              }
            },
            onGeolocationPermissionsShowPrompt: (controller, origin) async {
              // ... (no changes here)
              return GeolocationPermissionShowPromptResponse(
                origin: origin,
                allow: true,
                retain: false,
              );
            },
            onScrollChanged: (controller, x, y) {
              // ... (no changes here)
              if (_isAnimatingBars) return;
              final double scrollDelta = y - lastScrollPosition;

              if (y <= 0) {
                _setBarsVisibility(true);
              } else if (scrollDelta > _scrollThreshold) {
                _setBarsVisibility(false);
              } else if (scrollDelta < -_scrollThreshold) {
                _setBarsVisibility(true);
              }
              lastScrollPosition = y.toDouble();
            },
          ),
          if (isLoading) Center(child: CircularProgressIndicator()),
        ],
      ),
      bottomNavigationBar: AnimatedContainer(
        duration: Duration(milliseconds: 250),
        height: showBars ? 56.0 : 0.0,
        child: BottomAppBar(
          color: Theme.of(context).colorScheme.surfaceContainer,
          elevation: 2,
          child: Row(
            children: [
              Expanded(
                  child: _buildIconButton(
                      Icons.home_outlined, _goHome, 'דף הבית')),
              Expanded(
                  child: _buildIconButton(Icons.arrow_back, () async {
                if (await _webViewController.canGoBack())
                  _webViewController.goBack();
              }, 'חזרה')),
              Expanded(
                  child: _buildIconButton(Icons.arrow_forward, () async {
                if (await _webViewController.canGoForward())
                  _webViewController.goForward();
              }, 'קדימה')),
              Expanded(
                  child: _buildIconButton(Icons.bookmark_add_outlined,
                      _addBookmark, 'הוסף סימניה')),
              Expanded(
                  child: _buildIconButton(
                      Icons.bookmarks_outlined, _openBookmarks, 'סימניות')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(
      IconData icon, VoidCallback onPressed, String tooltip) {
    return IconButton(
      icon: Icon(icon,
          size: 24, color: Theme.of(context).colorScheme.onSurfaceVariant),
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }
}

class BookmarksPage extends StatelessWidget {
  // ... (no changes in BookmarksPage)
  final List<Map<String, String>> bookmarks;
  final Function(Map<String, String>) onSelect;
  final Function(Map<String, String>) onDelete;

  BookmarksPage({
    required this.bookmarks,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('סימניות'),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: bookmarks.isEmpty
            ? Center(
                child: Text(
                  'אין סימניות שמורות.',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                itemCount: bookmarks.length,
                itemBuilder: (context, index) {
                  var bookmark = bookmarks[index];
                  return Card(
                    margin:
                        EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    elevation: 2,
                    child: ListTile(
                      leading: Icon(Icons.bookmark,
                          color: Theme.of(context).colorScheme.primary),
                      title: Text(
                        bookmark['name']!,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      subtitle: Text(
                        bookmark['url']!,
                        style: TextStyle(color: Colors.grey.shade700),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        onSelect(bookmark);
                      },
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: Colors.red.shade400),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('אישור מחיקה'),
                              content: Text(
                                  'האם למחוק את הסימניה "${bookmark['name']!}"?'),
                              actions: <Widget>[
                                TextButton(
                                  child: Text('ביטול'),
                                  onPressed: () => Navigator.of(ctx).pop(),
                                ),
                                TextButton(
                                  child: Text('מחק',
                                      style: TextStyle(color: Colors.red)),
                                  onPressed: () {
                                    onDelete(bookmark);
                                    Navigator.of(ctx).pop();
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
