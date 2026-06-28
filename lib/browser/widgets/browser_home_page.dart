import 'package:flutter/material.dart';

import '../models/bookmark.dart';
import '../services/browser_text_direction.dart';

class BrowserHomePage extends StatefulWidget {
  const BrowserHomePage({
    super.key,
    required this.onNavigate,
    this.recentSearches = const <String>[],
    this.bookmarks = const <Bookmark>[],
  });

  final ValueChanged<String> onNavigate;
  final List<String> recentSearches;
  final List<Bookmark> bookmarks;

  @override
  State<BrowserHomePage> createState() => _BrowserHomePageState();
}

class _BrowserHomePageState extends State<BrowserHomePage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  BrowserResolvedTextDirection _textDirection = BrowserTextDirection.rtl;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleInputChanged);
    _focusNode.addListener(_handleFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleInputChanged);
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleInputChanged() {
    final next = BrowserTextDirection.resolve(_controller.text);
    if (!mounted) {
      return;
    }
    setState(() => _textDirection = next);
  }

  void _handleFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _submit([String? value]) {
    final input = (value ?? _controller.text).trim();
    if (input.isEmpty) {
      return;
    }
    FocusScope.of(context).unfocus();
    widget.onNavigate(input);
  }

  void _clearSearch() {
    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final suggestions = _suggestions();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colorScheme.surface),
        child: Stack(
          children: [
            const Positioned.fill(child: _HomeBackdrop()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 640;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(18, compact ? 28 : 52, 18, 96),
                    child: Column(
                      children: [
                        const Spacer(flex: 2),
                        Text(
                          'Net Flow',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        SizedBox(height: compact ? 18 : 26),
                        TextField(
                          key: const Key('browser-home-search-field'),
                          controller: _controller,
                          focusNode: _focusNode,
                          autofocus: false,
                          textInputAction: TextInputAction.search,
                          keyboardType: TextInputType.url,
                          textDirection: _textDirection.textDirection,
                          textAlign: _textDirection.textAlign,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 19,
                            fontWeight: FontWeight.w500,
                            height: 1.12,
                          ),
                          minLines: 1,
                          maxLines: 1,
                          cursorColor: colorScheme.primary,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: 'חיפוש או כתובת אתר',
                            hintStyle: TextStyle(
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.86,
                              ),
                              fontSize: 19,
                              fontWeight: FontWeight.w400,
                            ),
                            border: _homeSearchLine(
                              colorScheme.primary.withValues(alpha: 0.76),
                            ),
                            enabledBorder: _homeSearchLine(
                              colorScheme.onSurface.withValues(alpha: 0.62),
                            ),
                            focusedBorder: _homeSearchLine(
                              colorScheme.primary,
                              width: 2.3,
                            ),
                            prefixIcon: IconButton(
                              tooltip: 'חפש',
                              icon: const Icon(Icons.search),
                              color: colorScheme.onSurface,
                              onPressed: _submit,
                            ),
                            suffixIcon: IconButton(
                              tooltip: 'נקה',
                              icon: const Icon(Icons.close),
                              color: colorScheme.onSurface,
                              onPressed: _clearSearch,
                            ),
                            prefixIconConstraints:
                                const BoxConstraints.tightFor(
                              width: 48,
                              height: 48,
                            ),
                            suffixIconConstraints:
                                const BoxConstraints.tightFor(
                              width: 48,
                              height: 48,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                          ),
                        ),
                        if (_focusNode.hasFocus && suggestions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _HomeSuggestionsPanel(
                            suggestions: suggestions,
                            onSelected: (suggestion) {
                              _controller.text = suggestion.value;
                              _submit(suggestion.value);
                            },
                            maxHeight: compact ? 168 : 220,
                          ),
                        ],
                        const Spacer(flex: 3),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_HomeSearchSuggestion> _suggestions() {
    final query = _controller.text.trim().toLowerCase();
    bool matches(String value) {
      return query.isEmpty || value.toLowerCase().contains(query);
    }

    final historySuggestions = widget.recentSearches
        .where(matches)
        .map(
          (item) => _HomeSearchSuggestion(
            title: item,
            value: item,
            icon: Icons.history,
          ),
        )
        .toList();
    final bookmarkSuggestions = widget.bookmarks
        .where(
          (bookmark) => matches(bookmark.title) || matches(bookmark.url),
        )
        .map(
          (bookmark) => _HomeSearchSuggestion(
            title: bookmark.title.isEmpty ? bookmark.url : bookmark.title,
            subtitle: bookmark.url,
            value: bookmark.url,
            icon: Icons.bookmark_outline,
          ),
        )
        .toList();

    return <_HomeSearchSuggestion>[
      ...historySuggestions,
      ...bookmarkSuggestions,
    ].take(6).toList(growable: false);
  }
}

class _HomeSearchSuggestion {
  const _HomeSearchSuggestion({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String value;
  final IconData icon;
}

class _HomeSuggestionsPanel extends StatelessWidget {
  const _HomeSuggestionsPanel({
    required this.suggestions,
    required this.onSelected,
    required this.maxHeight,
  });

  final List<_HomeSearchSuggestion> suggestions;
  final ValueChanged<_HomeSearchSuggestion> onSelected;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      key: const Key('browser-home-suggestions-panel'),
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.72),
          border: Border.symmetric(
            horizontal: BorderSide(
              color: colorScheme.onSurface.withValues(alpha: 0.26),
            ),
          ),
        ),
        child: ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return ListTile(
              dense: true,
              leading: Icon(suggestion.icon, size: 20),
              title: Text(
                suggestion.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: suggestion.subtitle == null
                  ? null
                  : Text(
                      suggestion.subtitle!,
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.86,
                        ),
                      ),
                    ),
              onTap: () => onSelected(suggestion),
            );
          },
        ),
      ),
    );
  }
}

UnderlineInputBorder _homeSearchLine(Color color, {double width = 1.3}) {
  return UnderlineInputBorder(
    borderSide: BorderSide(color: color, width: width),
  );
}

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _HomeBackdropPainter(Theme.of(context).colorScheme),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _HomeBackdropPainter extends CustomPainter {
  const _HomeBackdropPainter(this.colorScheme);

  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          colorScheme.primaryContainer.withValues(alpha: 0.44),
          colorScheme.surface,
          colorScheme.tertiaryContainer.withValues(alpha: 0.34),
          colorScheme.secondaryContainer.withValues(alpha: 0.28),
        ],
        stops: const [0, 0.36, 0.72, 1],
      ).createShader(rect);

    canvas.drawRect(rect, backgroundPaint);

    _drawFlowGrid(canvas, size);
    _drawSoftBand(
      canvas,
      size,
      color: colorScheme.primary.withValues(alpha: 0.11),
      width: 30,
      startY: size.height * 0.18,
      controlYOffset: -52,
      endY: size.height * 0.36,
    );
    _drawSoftBand(
      canvas,
      size,
      color: colorScheme.tertiary.withValues(alpha: 0.10),
      width: 22,
      startY: size.height * 0.62,
      controlYOffset: 64,
      endY: size.height * 0.47,
    );
    _drawSoftBand(
      canvas,
      size,
      color: colorScheme.secondary.withValues(alpha: 0.08),
      width: 16,
      startY: size.height * 0.82,
      controlYOffset: -34,
      endY: size.height * 0.70,
    );

    _drawNetwork(canvas, size);
    _drawBubbles(canvas, size);
    _drawFlowFocus(canvas, size);
  }

  void _drawFlowGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colorScheme.primary.withValues(alpha: 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final highlightPaint = Paint()
      ..color = colorScheme.tertiary.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final step = size.shortestSide < 420 ? 54.0 : 68.0;
    for (var x = -step; x < size.width + step; x += step) {
      final path = Path()
        ..moveTo(x, 0)
        ..quadraticBezierTo(
          x + 12,
          size.height * 0.42,
          x - 6,
          size.height,
        );
      canvas.drawPath(path, paint);
    }

    for (var y = size.height * 0.08; y < size.height; y += step) {
      final path = Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(
          size.width * 0.45,
          y - 14,
          size.width,
          y + 8,
        );
      canvas.drawPath(path, paint);
    }

    final focusPath = Path()
      ..moveTo(size.width * 0.07, size.height * 0.54)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.47,
        size.width * 0.93,
        size.height * 0.56,
      );
    canvas.drawPath(focusPath, highlightPaint);
  }

  void _drawSoftBand(
    Canvas canvas,
    Size size, {
    required Color color,
    required double width,
    required double startY,
    required double controlYOffset,
    required double endY,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width;
    final path = Path()
      ..moveTo(size.width + width, startY)
      ..cubicTo(
        size.width * 0.72,
        startY + controlYOffset,
        size.width * 0.42,
        endY - controlYOffset,
        -width,
        endY,
      );

    canvas.drawPath(path, paint);
  }

  void _drawNetwork(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = colorScheme.primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final nodePaint = Paint()
      ..color = colorScheme.surface.withValues(alpha: 0.72)
      ..style = PaintingStyle.fill;
    final nodeBorderPaint = Paint()
      ..color = colorScheme.primary.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final points = [
      Offset(size.width * 0.10, size.height * 0.30),
      Offset(size.width * 0.24, size.height * 0.22),
      Offset(size.width * 0.38, size.height * 0.31),
      Offset(size.width * 0.55, size.height * 0.24),
      Offset(size.width * 0.73, size.height * 0.34),
      Offset(size.width * 0.88, size.height * 0.27),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, linePaint);

    for (final point in points) {
      canvas.drawCircle(point, 4.6, nodePaint);
      canvas.drawCircle(point, 4.6, nodeBorderPaint);
    }
  }

  void _drawBubbles(Canvas canvas, Size size) {
    final bubbles = [
      (
        Offset(size.width * 0.15, size.height * 0.56),
        22.0,
        colorScheme.primary
      ),
      (
        Offset(size.width * 0.31, size.height * 0.70),
        13.0,
        colorScheme.tertiary
      ),
      (
        Offset(size.width * 0.58, size.height * 0.17),
        18.0,
        colorScheme.secondary
      ),
      (
        Offset(size.width * 0.83, size.height * 0.48),
        11.0,
        colorScheme.primary
      ),
      (
        Offset(size.width * 0.90, size.height * 0.79),
        26.0,
        colorScheme.tertiary
      ),
    ];

    for (final bubble in bubbles) {
      final paint = Paint()
        ..color = bubble.$3.withValues(alpha: 0.09)
        ..style = PaintingStyle.stroke
        ..strokeWidth = bubble.$2 > 20 ? 1.5 : 1.1;
      final fillPaint = Paint()
        ..color = bubble.$3.withValues(alpha: 0.028)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(bubble.$1, bubble.$2, fillPaint);
      canvas.drawCircle(bubble.$1, bubble.$2, paint);
    }
  }

  void _drawFlowFocus(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.78, size.height * 0.66);
    final fillPaint = Paint()
      ..color = colorScheme.surface.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final ringPaint = Paint()
      ..color = colorScheme.primary.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final accentPaint = Paint()
      ..color = colorScheme.tertiary.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.2;

    canvas.drawCircle(center, 38, fillPaint);
    canvas.drawCircle(center, 38, ringPaint);
    canvas.drawCircle(center.translate(-2, 1), 24, ringPaint);
    canvas.drawCircle(center.translate(-3, 2), 9, ringPaint);

    final flowPath = Path()
      ..moveTo(center.dx - 42, center.dy - 8)
      ..cubicTo(
        center.dx - 18,
        center.dy - 24,
        center.dx + 13,
        center.dy - 20,
        center.dx + 34,
        center.dy - 34,
      );
    canvas.drawPath(flowPath, accentPaint);

    final exitPath = Path()
      ..moveTo(center.dx - 34, center.dy + 30)
      ..cubicTo(
        center.dx - 8,
        center.dy + 16,
        center.dx + 19,
        center.dy + 21,
        center.dx + 43,
        center.dy + 4,
      );
    canvas.drawPath(exitPath, accentPaint);
  }

  @override
  bool shouldRepaint(covariant _HomeBackdropPainter oldDelegate) {
    return oldDelegate.colorScheme != colorScheme;
  }
}
