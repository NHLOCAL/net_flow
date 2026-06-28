import 'package:flutter/material.dart';

import '../models/bookmark.dart';
import '../models/browser_state.dart';

class BrowserMenuSheet extends StatefulWidget {
  const BrowserMenuSheet({
    super.key,
    required this.state,
    required this.bookmarks,
    required this.onNavigate,
    required this.onBack,
    required this.onForward,
    required this.onReload,
    required this.onStop,
    required this.onHome,
    required this.onAddBookmark,
    required this.onOpenBookmark,
    required this.onDeleteBookmark,
    required this.onShowSitePermissions,
  });

  final BrowserState state;
  final List<Bookmark> bookmarks;
  final ValueChanged<String> onNavigate;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onReload;
  final VoidCallback onStop;
  final VoidCallback onHome;
  final VoidCallback onAddBookmark;
  final ValueChanged<Bookmark> onOpenBookmark;
  final ValueChanged<Bookmark> onDeleteBookmark;
  final VoidCallback onShowSitePermissions;

  @override
  State<BrowserMenuSheet> createState() => _BrowserMenuSheetState();
}

class _BrowserMenuSheetState extends State<BrowserMenuSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _isHomeUrl(widget.state.currentUrl)
          ? ''
          : widget.state.currentUrl,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'פתח',
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () => _submit(_controller.text),
                    ),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _ActionGrid(
                  children: [
                    _ActionButton(
                      icon: Icons.arrow_forward,
                      label: 'חזרה',
                      onPressed:
                          widget.state.canGoBack ? _run(widget.onBack) : null,
                    ),
                    _ActionButton(
                      icon: Icons.arrow_back,
                      label: 'קדימה',
                      onPressed: widget.state.canGoForward
                          ? _run(widget.onForward)
                          : null,
                    ),
                    _ActionButton(
                      icon:
                          widget.state.isLoading ? Icons.close : Icons.refresh,
                      label: widget.state.isLoading ? 'עצור' : 'רענן',
                      onPressed: _run(
                        widget.state.isLoading
                            ? widget.onStop
                            : widget.onReload,
                      ),
                    ),
                    _ActionButton(
                      icon: Icons.home_outlined,
                      label: 'בית',
                      onPressed: _run(widget.onHome),
                    ),
                    _ActionButton(
                      icon: Icons.bookmark_add_outlined,
                      label: 'שמור',
                      onPressed: _run(widget.onAddBookmark),
                    ),
                    _ActionButton(
                      icon: Icons.verified_user_outlined,
                      label: 'הרשאות',
                      onPressed: _run(widget.onShowSitePermissions),
                    ),
                    _ActionButton(
                      icon: Icons.download_outlined,
                      label: 'הורדות',
                      onPressed: _run(() {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('הורדות מופיעות בהתראות Android'),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
                if (widget.bookmarks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'סימניות',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.bookmarks.length,
                      itemBuilder: (context, index) {
                        final bookmark = widget.bookmarks[index];
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
                          onTap: _run(() => widget.onOpenBookmark(bookmark)),
                          trailing: IconButton(
                            tooltip: 'מחק סימניה',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => widget.onDeleteBookmark(bookmark),
                          ),
                        );
                      },
                    ),
                  ),
                ],
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

  bool _isHomeUrl(String url) {
    return url == 'netflow://home' || url == 'about:blank';
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.05,
      children: children,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 4),
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
