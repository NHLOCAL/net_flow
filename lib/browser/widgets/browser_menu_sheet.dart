import 'package:flutter/material.dart';

import '../models/bookmark.dart';
import '../models/browser_state.dart';
import '../services/browser_text_direction.dart';

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
  late BrowserResolvedTextDirection _textDirection;
  bool _showBookmarks = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _isHomeUrl(widget.state.currentUrl) ? '' : widget.state.currentUrl,
    );
    _textDirection = BrowserTextDirection.resolve(_controller.text);
    _controller.addListener(_syncTextDirection);
    _visibleBookmarks = List<Bookmark>.of(widget.bookmarks);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncTextDirection);
    _controller.dispose();
    super.dispose();
  }

  void _syncTextDirection() {
    final next = BrowserTextDirection.resolve(_controller.text);
    if (next == _textDirection || !mounted) {
      return;
    }
    setState(() => _textDirection = next);
  }

  @override
  void didUpdateWidget(covariant BrowserMenuSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldText = _isHomeUrl(oldWidget.state.currentUrl)
        ? ''
        : oldWidget.state.currentUrl;
    if (oldWidget.state.currentUrl != widget.state.currentUrl &&
        _controller.text == oldText) {
      _controller.text =
          _isHomeUrl(widget.state.currentUrl) ? '' : widget.state.currentUrl;
      _textDirection = BrowserTextDirection.resolve(_controller.text);
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
    final colorScheme = Theme.of(context).colorScheme;
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
                  textDirection: _textDirection.textDirection,
                  textAlign: _textDirection.textAlign,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.12,
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  cursorColor: colorScheme.primary,
                  onSubmitted: _submit,
                  decoration: InputDecoration(
                    hintText: 'חיפוש או כתובת אתר',
                    hintStyle: TextStyle(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.86,
                      ),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: const Key('browser-address-clear-button'),
                          tooltip: 'נקה',
                          icon: const Icon(Icons.close),
                          color: colorScheme.onSurface,
                          onPressed: _controller.clear,
                        ),
                        IconButton(
                          key: const Key('browser-address-search-button'),
                          tooltip: 'חפש',
                          icon: const Icon(Icons.search),
                          color: colorScheme.onSurface,
                          onPressed: () => _submit(_controller.text),
                        ),
                      ],
                    ),
                    isDense: true,
                    border: _menuSearchLine(
                      colorScheme.primary.withValues(alpha: 0.76),
                    ),
                    enabledBorder: _menuSearchLine(
                      colorScheme.onSurface.withValues(alpha: 0.62),
                    ),
                    focusedBorder: _menuSearchLine(
                      colorScheme.primary,
                      width: 2.3,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
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

UnderlineInputBorder _menuSearchLine(Color color, {double width = 1.3}) {
  return UnderlineInputBorder(
    borderSide: BorderSide(color: color, width: width),
  );
}

class _CompactActionRow extends StatelessWidget {
  const _CompactActionRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rowChildren = <Widget>[];
    for (var index = 0; index < children.length; index += 1) {
      if (index > 0) {
        rowChildren.add(_ActionSeparator(index: index - 1));
      }
      rowChildren.add(
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: children[index],
          ),
        ),
      );
    }

    return Row(
      children: rowChildren,
    );
  }
}

class _ActionSeparator extends StatelessWidget {
  const _ActionSeparator({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      key: Key('browser-menu-action-separator-$index'),
      width: 1,
      height: 30,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.outlineVariant.withValues(alpha: 0.9),
        ),
      ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
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
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
