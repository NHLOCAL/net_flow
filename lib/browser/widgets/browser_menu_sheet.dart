import 'package:flutter/material.dart';

import '../models/bookmark.dart';
import '../models/browser_state.dart';

class BrowserMenuSheet extends StatefulWidget {
  const BrowserMenuSheet({
    super.key,
    required this.state,
    required this.bookmarks,
    required this.onNavigate,
    required this.onAddBookmark,
    required this.onOpenBookmark,
    required this.onDeleteBookmark,
    required this.onShowSitePermissions,
  });

  final BrowserState state;
  final List<Bookmark> bookmarks;
  final ValueChanged<String> onNavigate;
  final VoidCallback onAddBookmark;
  final ValueChanged<Bookmark> onOpenBookmark;
  final ValueChanged<Bookmark> onDeleteBookmark;
  final VoidCallback onShowSitePermissions;

  @override
  State<BrowserMenuSheet> createState() => _BrowserMenuSheetState();
}

class _BrowserMenuSheetState extends State<BrowserMenuSheet> {
  late final TextEditingController _controller;
  late List<Bookmark> _visibleBookmarks;
  bool _showBookmarks = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _isHomeUrl(widget.state.currentUrl)
          ? ''
          : widget.state.currentUrl,
    );
    _visibleBookmarks = List<Bookmark>.of(widget.bookmarks);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BrowserMenuSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldText =
        _isHomeUrl(oldWidget.state.currentUrl) ? '' : oldWidget.state.currentUrl;
    if (oldWidget.state.currentUrl != widget.state.currentUrl &&
        _controller.text == oldText) {
      _controller.text =
          _isHomeUrl(widget.state.currentUrl) ? '' : widget.state.currentUrl;
    }
    if (oldWidget.bookmarks != widget.bookmarks) {
      _visibleBookmarks = List<Bookmark>.of(widget.bookmarks);
      if (_visibleBookmarks.isEmpty) {
        _showBookmarks = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottomInset),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('browser-address-field'),
                  controller: _controller,
                  autofocus: true,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onSubmitted: _submit,
                  decoration: InputDecoration(
                    hintText: 'חיפוש או כתובת אתר',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: const Key('browser-address-clear-button'),
                          tooltip: 'נקה',
                          icon: const Icon(Icons.close),
                          onPressed: _controller.clear,
                        ),
                        IconButton(
                          key: const Key('browser-address-search-button'),
                          tooltip: 'חפש',
                          icon: const Icon(Icons.search),
                          onPressed: () => _submit(_controller.text),
                        ),
                      ],
                    ),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_showBookmarks && _visibleBookmarks.isNotEmpty) ...[
                  _BookmarksPanel(
                    key: const Key('browser-bookmarks-panel'),
                    bookmarks: _visibleBookmarks,
                    onOpenBookmark: widget.onOpenBookmark,
                    onDeleteBookmark: _deleteBookmark,
                    runAndClose: _run,
                  ),
                  const SizedBox(height: 10),
                ],
                _CompactActionRow(
                  key: const Key('browser-menu-action-row'),
                  children: [
                    _ActionButton(
                      icon: Icons.bookmark_add_outlined,
                      label: 'שמור',
                      onPressed: _run(widget.onAddBookmark),
                    ),
                    _ActionButton(
                      key: const Key('browser-bookmarks-button'),
                      icon: Icons.bookmarks_outlined,
                      label: 'סימניות',
                      onPressed: _visibleBookmarks.isEmpty
                          ? null
                          : () => setState(() {
                                _showBookmarks = !_showBookmarks;
                              }),
                    ),
                    _ActionButton(
                      icon: Icons.verified_user_outlined,
                      label: 'הרשאות',
                      onPressed: _run(widget.onShowSitePermissions),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit(String value) {
    Navigator.of(context).pop();
    widget.onNavigate(value);
  }

  VoidCallback _run(VoidCallback callback) {
    return () {
      Navigator.of(context).pop();
      callback();
    };
  }

  void _deleteBookmark(Bookmark bookmark) {
    setState(() {
      _visibleBookmarks =
          _visibleBookmarks.where((item) => item.url != bookmark.url).toList();
      if (_visibleBookmarks.isEmpty) {
        _showBookmarks = false;
      }
    });
    widget.onDeleteBookmark(bookmark);
  }

  bool _isHomeUrl(String url) {
    return url == 'netflow://home' || url == 'about:blank';
  }
}

class _CompactActionRow extends StatelessWidget {
  const _CompactActionRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final child in children)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: child,
            ),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarksPanel extends StatelessWidget {
  const _BookmarksPanel({
    super.key,
    required this.bookmarks,
    required this.onOpenBookmark,
    required this.onDeleteBookmark,
    required this.runAndClose,
  });

  final List<Bookmark> bookmarks;
  final ValueChanged<Bookmark> onOpenBookmark;
  final ValueChanged<Bookmark> onDeleteBookmark;
  final VoidCallback Function(VoidCallback callback) runAndClose;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: bookmarks.length,
          itemBuilder: (context, index) {
            final bookmark = bookmarks[index];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.bookmark_outline),
              title: Text(
                bookmark.title,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                bookmark.url,
                textDirection: TextDirection.ltr,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: runAndClose(() => onOpenBookmark(bookmark)),
              trailing: IconButton(
                tooltip: 'מחק סימניה',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onDeleteBookmark(bookmark),
              ),
            );
          },
        ),
      ),
    );
  }
}
