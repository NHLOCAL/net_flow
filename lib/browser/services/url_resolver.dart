import '../models/browser_settings.dart';

class BrowserUrlResolver {
  const BrowserUrlResolver({
    this.settings = const BrowserSettings.defaults(),
  });

  final BrowserSettings settings;

  String resolve(String input) {
    final value = input.trim();
    if (value.isEmpty) {
      return settings.homeUrl;
    }

    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return value;
    }

    if (_looksLikeDomain(value)) {
      return 'https://$value';
    }

    return settings.searchUrlTemplate.replaceAll(
      '{query}',
      Uri.encodeComponent(value),
    );
  }

  bool isExternalScheme(Uri uri) {
    return uri.scheme.isNotEmpty &&
        uri.scheme != 'http' &&
        uri.scheme != 'https' &&
        uri.scheme != 'about' &&
        uri.scheme != 'data' &&
        uri.scheme != 'file';
  }

  bool _looksLikeDomain(String value) {
    if (value.contains(' ') || value.contains('\n')) {
      return false;
    }

    final uri = Uri.tryParse('https://$value');
    return uri != null &&
        uri.host.contains('.') &&
        !uri.host.startsWith('.') &&
        !uri.host.endsWith('.');
  }
}
