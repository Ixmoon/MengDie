/// A lightweight class to hold synchronization metadata.
class SyncMeta {
  final dynamic id; // Can be int for chats or String for api_configs/users (uuid)
  final DateTime createdAt;
  final DateTime updatedAt;

  SyncMeta({required this.id, required this.createdAt, required this.updatedAt});

  // Use a composite key for accurate identification.
  // IMPORTANT: Always convert DateTime to UTC for comparison to avoid timezone issues.
  dynamic get key => (id, createdAt.toUtc());
}