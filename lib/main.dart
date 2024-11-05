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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.purple,
          elevation: 4,
        ),
        bottomAppBarTheme: BottomAppBarTheme(
          color: Colors.purple.shade700,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.purple,
        ),
        iconTheme: IconThemeData(
          color: Colors.white,
          size: 24,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
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
  List<Map<String, String>> bookmarks = [];
  double lastScrollPosition = 0;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _urlController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _urlController.text.length,
          );
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
    FocusScope.of(context).unfocus();
  }

  Future<void> _loadBookmarks() async {
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
        TextEditingController nameController = TextEditingController();
        nameController.text = _getDomain(url);
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            title: Text('הוסף סימניה'),
            content: TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'שם הסימניה',
                filled: true,
                fillColor: Colors.grey.shade200,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              ),
              textDirection: TextDirection.rtl,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  String name = nameController.text.trim();
                  if (name.isEmpty) return;

                  setState(() {
                    bookmarks.add({
                      'name': name,
                      'url': url,
                    });
                    _saveBookmarks();
                  });
                  Navigator.of(context).pop();
                },
                child: Text(
                  'שמור',
                  style: TextStyle(color: Theme.of(context).primaryColor),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'ביטול',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getDomain(String url) {
    try {
      Uri uri = Uri.parse(url);
      return uri.host.isNotEmpty ? uri.host : url;
    } catch (e) {
      return url;
    }
  }

  void _openBookmarks() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookmarksPage(
          bookmarks: bookmarks,
          onSelect: (bookmark) {
            _webViewController.loadUrl(
              urlRequest: URLRequest(url: WebUri(bookmark['url']!)),
            );
            _urlController.text = bookmark['url']!;
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
      urlRequest: URLRequest(url: WebUri('about:blank')),
    );
    setState(() {
      _urlController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showBars
          ? AppBar(
              title: Container(
                height: 50.0,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _urlController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'הזן כתובת URL או מונח חיפוש',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                  ),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (value) => _navigateToUrl(),
                  style: TextStyle(color: Colors.black87),
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.search),
                  onPressed: _navigateToUrl,
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri('about:blank')),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onLoadStart: (controller, url) {
              setState(() {
                isLoading = true;
              });
            },
            onLoadStop: (controller, url) async {
              setState(() {
                isLoading = false;
                _urlController.text = url?.toString() ?? '';
              });
            },
            onReceivedError: (controller, request, error) {
              setState(() {
                isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('הטעינה נכשלה: ${error.description}')),
              );
            },
            onGeolocationPermissionsShowPrompt: (controller, origin) async {
              return GeolocationPermissionShowPromptResponse(
                origin: origin,
                allow: true,
                retain: false,
              );
            },
            onScrollChanged: (controller, x, y) {
              if (y > lastScrollPosition && y - lastScrollPosition > 10) {
                if (showBars) {
                  setState(() {
                    showBars = false;
                  });
                }
              } else if (y < lastScrollPosition &&
                  lastScrollPosition - y > 10) {
                if (!showBars) {
                  setState(() {
                    showBars = true;
                  });
                }
              }
              lastScrollPosition = y.toDouble();
            },
          ),
          if (isLoading)
            Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary),
              ),
            ),
        ],
      ),
      bottomNavigationBar: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        height: showBars ? 60.0 : 0.0,
        child: showBars
            ? BottomAppBar(
                color: Theme.of(context).bottomAppBarTheme.color,
                elevation: 8,
                shape: CircularNotchedRectangle(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                          child:
                              _buildIconButton(Icons.home, _goHome, 'דף הבית')),
                      Expanded(
                          child: _buildIconButton(Icons.arrow_back, () async {
                        if (await _webViewController.canGoBack()) {
                          _webViewController.goBack();
                        }
                      }, 'חזרה')),
                      Expanded(
                          child:
                              _buildIconButton(Icons.arrow_forward, () async {
                        if (await _webViewController.canGoForward()) {
                          _webViewController.goForward();
                        }
                      }, 'קדימה')),
                      Expanded(
                          child: _buildIconButton(Icons.refresh, () {
                        _webViewController.reload();
                      }, 'רענן')),
                      Expanded(
                          child: _buildIconButton(
                              Icons.bookmark_add, _addBookmark, 'הוסף סימניה')),
                      Expanded(
                          child: _buildIconButton(
                              Icons.bookmarks, _openBookmarks, 'סימניות')),
                    ],
                  ),
                ),
              )
            : SizedBox.shrink(),
      ),
    );
  }

  Widget _buildIconButton(
      IconData icon, VoidCallback onPressed, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        color: Colors.white,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(),
        tooltip: tooltip,
      ),
    );
  }
}

class BookmarksPage extends StatelessWidget {
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
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              )
            : ListView.builder(
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
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        bookmark['url']!,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      onTap: () {
                        onSelect(bookmark);
                      },
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          onDelete(bookmark);
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
