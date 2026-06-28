class BrowserSettings {
  const BrowserSettings({
    required this.homeUrl,
    required this.searchUrlTemplate,
    required this.rememberPermissions,
    required this.desktopModeEnabled,
  });

  const BrowserSettings.defaults()
      : homeUrl = 'netflow://home',
        searchUrlTemplate = 'https://www.google.com/search?q={query}',
        rememberPermissions = true,
        desktopModeEnabled = false;

  final String homeUrl;
  final String searchUrlTemplate;
  final bool rememberPermissions;
  final bool desktopModeEnabled;

  factory BrowserSettings.fromJson(Map<String, dynamic> json) {
    return BrowserSettings(
      homeUrl: (json['homeUrl'] ?? 'netflow://home').toString(),
      searchUrlTemplate: (json['searchUrlTemplate'] ??
              'https://www.google.com/search?q={query}')
          .toString(),
      rememberPermissions: json['rememberPermissions'] != false,
      desktopModeEnabled: json['desktopModeEnabled'] == true,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'homeUrl': homeUrl,
      'searchUrlTemplate': searchUrlTemplate,
      'rememberPermissions': rememberPermissions,
      'desktopModeEnabled': desktopModeEnabled,
    };
  }
}
