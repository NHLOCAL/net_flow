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
      child: Container(
        color: colorScheme.surface,
        child: SafeArea(
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
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    SizedBox(height: compact ? 18 : 26),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: colorScheme.outlineVariant,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
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
      ),
    );
  }
}
