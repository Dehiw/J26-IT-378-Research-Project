/// A hive the user can pick on the Hive Sound Monitor.
class HiveOption {
  /// Stable id. In the real app this is the backend hive id.
  final String id;

  /// What the user sees, such as "Hive Box #01" or "Hive H-001".
  final String name;

  final String apiary;

  const HiveOption({
    required this.id,
    required this.name,
    required this.apiary,
  });
}
