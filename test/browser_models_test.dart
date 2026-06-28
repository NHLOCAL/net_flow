import 'package:flutter_test/flutter_test.dart';
import 'package:net_flow/browser/models/bookmark.dart';
import 'package:net_flow/browser/models/browser_settings.dart';
import 'package:net_flow/browser/models/site_permission_decision.dart';

void main() {
  test('Bookmark migrates existing name/url JSON', () {
    final bookmark = Bookmark.fromJson({
      'name': 'נטפרי',
      'url': 'https://netfree.link',
    });

    expect(bookmark.title, 'נטפרי');
    expect(bookmark.url, 'https://netfree.link');
    expect(bookmark.toJson(), {
      'title': 'נטפרי',
      'url': 'https://netfree.link',
    });
  });

  test('BrowserSettings has compact Android browser defaults', () {
    const settings = BrowserSettings.defaults();

    expect(settings.homeUrl, 'about:blank');
    expect(
        settings.searchUrlTemplate, 'https://www.google.com/search?q={query}');
    expect(settings.rememberPermissions, isTrue);
    expect(settings.desktopModeEnabled, isFalse);
  });

  test('SitePermissionDecision round trips JSON', () {
    const decision = SitePermissionDecision(
      origin: 'https://example.com',
      resource: SitePermissionResource.camera,
      action: SitePermissionAction.allow,
      persist: true,
    );

    expect(SitePermissionDecision.fromJson(decision.toJson()), decision);
  });
}
