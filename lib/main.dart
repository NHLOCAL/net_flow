import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(MyBrowserApp());
}

class MyBrowserApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Mini Browser',
      theme: ThemeData(
        primarySwatch: Colors.blue,
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
  late final WebViewController _controller;
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool isLoading = true;
  bool showBars = true;
  List<Map<String, String>> bookmarks = [];

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ScrollChannel',
        onMessageReceived: (JavaScriptMessage message) {
          // ההודעה צריכה להיות 'up' או 'down'
          if (message.message == 'up') {
            setState(() {
              showBars = true;
            });
          } else if (message.message == 'down') {
            setState(() {
              showBars = false;
            });
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              isLoading = true;
            });
          },
          onPageFinished: (url) {
            setState(() {
              isLoading = false;
              _urlController.text = url;
            });
            // הזרקת JavaScript לזיהוי גלילה
            _injectScrollListener();
          },
        ),
      )
      ..loadRequest(Uri.parse('about:blank')); // דף בית ריק

    // הוספת מאזין לפוקוס כדי לנקות את שדה החיפוש
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _urlController.clear();
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

  // פונקציה לבדיקה אם הקלט הוא כתובת URL תקנית
  bool isValidUrl(String input) {
    // ביטוי רגולרי מתקדם לזיהוי כתובות URL
    final RegExp urlRegExp = RegExp(
      r'^(https?:\/\/)?' // אפשרות לסכמה http או https
      r'((([a-zA-Z0-9\-]+\.)+[a-zA-Z]{2,}))' // שם דומיין
      r'(\/[^\s]*)?$', // אפשרות לנתיב
      caseSensitive: false,
    );
    return urlRegExp.hasMatch(input);
  }

  void _navigateToUrl() {
    String input = _urlController.text.trim();
    String url;

    if (input.isEmpty) return;

    if (isValidUrl(input)) {
      // הקלט הוא כתובת URL תקנית
      if (input.startsWith('http://') || input.startsWith('https://')) {
        url = input;
      } else {
        // אם אין סכמה, נוסיף אוטומטית https://
        url = 'https://$input';
      }
    } else {
      // הקלט אינו כתובת URL תקנית, נבצע חיפוש בגוגל
      String query = Uri.encodeComponent(input);
      url = 'https://www.google.com/search?q=$query';
    }

    _controller.loadRequest(Uri.parse(url));
    FocusScope.of(context).unfocus(); // הסתרת המקלדת
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
        return AlertDialog(
          title: Text('הוסף סימניה'),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(hintText: 'שם הסימניה'),
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
              child: Text('שמור'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('ביטול'),
            ),
          ],
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
            _controller.loadRequest(Uri.parse(bookmark['url']!));
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

  void _injectScrollListener() {
    String js = """
      (function() {
        var lastScrollTop = 0;
        window.addEventListener('scroll', function() {
          var scrollTop = window.pageYOffset || document.documentElement.scrollTop;
          if (scrollTop > lastScrollTop){
            // הגלילה למטה
            ScrollChannel.postMessage('down');
          } else {
            // הגלילה למעלה
            ScrollChannel.postMessage('up');
          }
          lastScrollTop = scrollTop <= 0 ? 0 : scrollTop; // עבור Chrome
        }, false);
      })();
    """;
    _controller.runJavaScript(js);
  }

  void _goHome() {
    _controller.loadRequest(Uri.parse('about:blank'));
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
                height: 40.0,
                child: TextField(
                  controller: _urlController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'הזן כתובת URL או מונח חיפוש',
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onChanged: (value) {
                    // ברגע שהמשתמש מתחיל להקליד, ננקה את השדה
                    if (_urlController.text.isNotEmpty) {
                      _urlController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _urlController.text.length),
                      );
                    }
                  },
                  onSubmitted: (value) => _navigateToUrl(),
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
      body: GestureDetector(
        onTap: () {
          // הסתרה או הצגה של הסרגלים בעת לחיצה על המסך
          setState(() {
            showBars = !showBars;
          });
        },
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (isLoading)
              Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        height: showBars ? 50.0 : 0.0, // הגדרת גובה קטן יותר
        child: showBars
            ? BottomAppBar(
                color: Colors.blue, // הגדרת צבע חדש לסרגל התחתון
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly, // הפחתת רווח בין הכפתורים
                  children: [
                    IconButton(
                      icon: Icon(Icons.home, size: 20.0), // כפתור דף הבית
                      onPressed: _goHome,
                    ),
                    IconButton(
                      icon: Icon(Icons.arrow_back, size: 20.0), // כפתור חזרה
                      onPressed: () async {
                        if (await _controller.canGoBack()) {
                          _controller.goBack();
                        }
                      },
                    ),
                    IconButton(
                      icon:
                          Icon(Icons.arrow_forward, size: 20.0), // כפתור קדימה
                      onPressed: () async {
                        if (await _controller.canGoForward()) {
                          _controller.goForward();
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, size: 20.0), // כפתור רענון
                      onPressed: () {
                        _controller.reload();
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.bookmark_add,
                          size: 20.0), // כפתור הוספת סימניה
                      onPressed: _addBookmark,
                    ),
                    IconButton(
                      icon: Icon(Icons.bookmarks,
                          size: 20.0), // כפתור פתיחת סימניות
                      onPressed: _openBookmarks,
                    ),
                  ],
                ),
              )
            : SizedBox.shrink(),
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
      ),
      body: bookmarks.isEmpty
          ? Center(child: Text('אין סימניות שמורות.'))
          : ListView.builder(
              itemCount: bookmarks.length,
              itemBuilder: (context, index) {
                var bookmark = bookmarks[index];
                return ListTile(
                  title: Text(bookmark['name']!),
                  subtitle: Text(bookmark['url']!),
                  onTap: () {
                    onSelect(bookmark);
                  },
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () {
                      onDelete(bookmark);
                    },
                  ),
                );
              },
            ),
    );
  }
}
