typedef JsonMap = Map<String, dynamic>;

class AdminPage {
  const AdminPage({
    required this.records,
    this.nextCursor,
    this.hasMore = false,
  });
  final List<AdminRecord> records;
  final String? nextCursor;
  final bool hasMore;
}

/// Backend resource row. The server owns the shape; every field returned by a
/// resource is retained so screens never synthesize server data.
class AdminRecord {
  const AdminRecord(this.values);
  final JsonMap values;
  String get id => values['id'] as String? ?? '';
  String? get name => values['name'] as String?;
  int get version => (values['version'] as num?)?.toInt() ?? 0;
  factory AdminRecord.fromJson(JsonMap json) =>
      AdminRecord(Map.unmodifiable(json));
}

class SetupStep {
  const SetupStep({required this.key, required this.done});
  final String key;
  final bool done;
  factory SetupStep.fromJson(JsonMap json) =>
      SetupStep(key: json['key'] as String, done: json['done'] as bool);
}

class PermissionGroup {
  const PermissionGroup({required this.module, required this.permissions});
  final String module;
  final List<PermissionItem> permissions;
  factory PermissionGroup.fromJson(JsonMap json) => PermissionGroup(
    module: json['module'] as String,
    permissions: (json['permissions'] as List)
        .map((item) => PermissionItem.fromJson(item as JsonMap))
        .toList(growable: false),
  );
}

class PermissionItem {
  const PermissionItem({required this.name, required this.action});
  final String name;
  final String action;
  factory PermissionItem.fromJson(JsonMap json) => PermissionItem(
    name: json['name'] as String,
    action: json['action'] as String,
  );
}
