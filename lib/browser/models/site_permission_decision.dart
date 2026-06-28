enum SitePermissionResource {
  camera,
  microphone,
  geolocation,
}

enum SitePermissionAction {
  allow,
  deny,
}

class SitePermissionDecision {
  const SitePermissionDecision({
    required this.origin,
    required this.resource,
    required this.action,
    required this.persist,
  });

  final String origin;
  final SitePermissionResource resource;
  final SitePermissionAction action;
  final bool persist;

  factory SitePermissionDecision.fromJson(Map<String, dynamic> json) {
    return SitePermissionDecision(
      origin: (json['origin'] ?? '').toString(),
      resource: SitePermissionResource.values.firstWhere(
        (value) => value.name == json['resource'],
        orElse: () => SitePermissionResource.geolocation,
      ),
      action: SitePermissionAction.values.firstWhere(
        (value) => value.name == json['action'],
        orElse: () => SitePermissionAction.deny,
      ),
      persist: json['persist'] == true,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'origin': origin,
      'resource': resource.name,
      'action': action.name,
      'persist': persist,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is SitePermissionDecision &&
        other.origin == origin &&
        other.resource == resource &&
        other.action == action &&
        other.persist == persist;
  }

  @override
  int get hashCode => Object.hash(origin, resource, action, persist);
}
