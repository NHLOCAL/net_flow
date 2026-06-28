import 'package:flutter_test/flutter_test.dart';
import 'package:net_flow/browser/models/site_permission_decision.dart';
import 'package:net_flow/browser/services/site_permission_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores and retrieves persistent decisions by origin and resource',
      () async {
    final store = SitePermissionStore(await SharedPreferences.getInstance());
    const decision = SitePermissionDecision(
      origin: 'https://example.com',
      resource: SitePermissionResource.microphone,
      action: SitePermissionAction.allow,
      persist: true,
    );

    await store.save(decision);

    expect(
      store.get(
        origin: 'https://example.com',
        resource: SitePermissionResource.microphone,
      ),
      decision,
    );
  });

  test('does not persist one-time decisions', () async {
    final store = SitePermissionStore(await SharedPreferences.getInstance());

    await store.save(const SitePermissionDecision(
      origin: 'https://example.com',
      resource: SitePermissionResource.geolocation,
      action: SitePermissionAction.allow,
      persist: false,
    ));

    expect(
      store.get(
        origin: 'https://example.com',
        resource: SitePermissionResource.geolocation,
      ),
      isNull,
    );
  });
}
