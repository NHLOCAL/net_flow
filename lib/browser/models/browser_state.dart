import 'browser_error.dart';

class BrowserState {
  const BrowserState({
    this.currentUrl = 'netflow://home',
    this.title = 'Net Flow',
    this.progress = 0,
    this.isLoading = false,
    this.canGoBack = false,
    this.canGoForward = false,
    this.error,
  });

  final String currentUrl;
  final String title;
  final double progress;
  final bool isLoading;
  final bool canGoBack;
  final bool canGoForward;
  final BrowserError? error;

  BrowserState copyWith({
    String? currentUrl,
    String? title,
    double? progress,
    bool? isLoading,
    bool? canGoBack,
    bool? canGoForward,
    BrowserError? error,
    bool clearError = false,
  }) {
    return BrowserState(
      currentUrl: currentUrl ?? this.currentUrl,
      title: title ?? this.title,
      progress: progress ?? this.progress,
      isLoading: isLoading ?? this.isLoading,
      canGoBack: canGoBack ?? this.canGoBack,
      canGoForward: canGoForward ?? this.canGoForward,
      error: clearError ? null : error ?? this.error,
    );
  }
}
