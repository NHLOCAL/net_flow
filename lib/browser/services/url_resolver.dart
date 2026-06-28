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
    if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return false;
    }

    final authority = value.split(RegExp(r'[/?#]')).first;
    if (authority.contains('@')) {
      return false;
    }

    return _isValidDomainHost(uri.host) || _isValidIpv4Host(uri.host);
  }

  bool _isValidDomainHost(String host) {
    final labels = host.split('.');
    if (labels.length < 2) {
      return false;
    }

    final labelPattern = RegExp(r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$');
    for (final label in labels) {
      if (!labelPattern.hasMatch(label)) {
        return false;
      }
    }

    final topLevelDomain = labels.last;
    return RegExp(r'^(?:[a-zA-Z]{2,63}|xn--[a-zA-Z0-9-]{2,59})$')
        .hasMatch(topLevelDomain);
  }

  bool _isValidIpv4Host(String host) {
    final parts = host.split('.');
    if (parts.length != 4) {
      return false;
    }

    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) {
        return false;
      }
    }
    return true;
  }
}
