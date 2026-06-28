import 'package:flutter/material.dart';

import '../services/browser_text_direction.dart';

class BrowserHomePage extends StatefulWidget {
  const BrowserHomePage({
    super.key,
    required this.onNavigate,
  });

  final ValueChanged<String> onNavigate;

  @override
  State<BrowserHomePage> createState() => _BrowserHomePageState();
}

class _BrowserHomePageState extends State<BrowserHomePage> {
  final TextEditingController _controller = TextEditingController();
  BrowserResolvedTextDirection _textDirection = BrowserTextDirection.rtl;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncTextDirection);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    });
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

  void _submit() {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      return;
    }
    FocusScope.of(context).unfocus();
    widget.onNavigate(input);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.86),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    colorScheme.primary.withValues(alpha: 0.10),
                                blurRadius: 28,
                                offset: const Offset(0, 14),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            key: const Key('browser-home-search-field'),
                            controller: _controller,
                            autofocus: false,
                            textInputAction: TextInputAction.search,
                            keyboardType: TextInputType.url,
                            textDirection: _textDirection.textDirection,
                            textAlign: _textDirection.textAlign,
                            minLines: 1,
                            maxLines: 1,
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              hintText: 'חיפוש או כתובת אתר',
                              border: InputBorder.none,
                              prefixIcon: IconButton(
                                tooltip: 'חפש',
                                icon: const Icon(Icons.search),
                                onPressed: _submit,
                              ),
                              suffixIcon: IconButton(
                                tooltip: 'נקה',
                                icon: const Icon(Icons.close),
                                onPressed: () => _controller.clear(),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
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
    _drawFilterGate(canvas, size);
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

  void _drawFilterGate(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.78, size.height * 0.66);
    final gateRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: 74,
        height: 92,
      ),
      const Radius.circular(24),
    );
    final gatePaint = Paint()
      ..color = colorScheme.surface.withValues(alpha: 0.42)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = colorScheme.primary.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final checkPaint = Paint()
      ..color = colorScheme.primary.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 4;

    canvas.drawRRect(gateRect, gatePaint);
    canvas.drawRRect(gateRect, borderPaint);

    final checkPath = Path()
      ..moveTo(center.dx - 18, center.dy + 2)
      ..lineTo(center.dx - 5, center.dy + 15)
      ..lineTo(center.dx + 20, center.dy - 16);
    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant _HomeBackdropPainter oldDelegate) {
    return oldDelegate.colorScheme != colorScheme;
  }
}
