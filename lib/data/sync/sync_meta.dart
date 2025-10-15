/// A lightweight class to hold synchronization metadata.
class SyncMeta {
  final dynamic
  id; // Can be int for chats or String for api_configs/users (uuid)
  final DateTime createdAt;
  final DateTime updatedAt;

  SyncMeta({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
  });

 // Use the id directly as the key, which can now be a business key like username or name.
 dynamic get key => id;
}
