import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/browser_error.dart';

class BrowserErrorView extends StatelessWidget {
  const BrowserErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onOpenExternally,
  });

  final BrowserError error;
  final VoidCallback onRetry;
  final VoidCallback onOpenExternally;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _iconFor(error.kind),
                  size: 44,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 14),
                Text(
                  error.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('נסה שוב'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: error.url));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('הכתובת הועתקה')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('העתק'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onOpenExternally,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('פתח בחוץ'),
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

  IconData _iconFor(BrowserErrorKind kind) {
    switch (kind) {
      case BrowserErrorKind.netfreeBlocked:
        return Icons.shield_outlined;
      case BrowserErrorKind.ssl:
        return Icons.lock_outline;
      case BrowserErrorKind.externalApp:
        return Icons.open_in_new_off_outlined;
      case BrowserErrorKind.load:
        return Icons.error_outline;
    }
  }
}
