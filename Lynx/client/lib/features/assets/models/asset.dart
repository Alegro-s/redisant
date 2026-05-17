class Asset {
  final String id;
  final String projectId;
  final String name;
  final String type; // 'sprite', 'script', 'sound'
  final int? size;
  final String? hash;
  final String? storagePath;
  final Map<String, dynamic> metadata;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Asset({
    required this.id,
    required this.projectId,
    required this.name,
    required this.type,
    this.size,
    this.hash,
    this.storagePath,
    this.metadata = const {},
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'],
      projectId: json['project_id'],
      name: json['name'],
      type: json['type'],
      size: json['size'],
      hash: json['hash'],
      storagePath: json['storage_path'],
      metadata: json['metadata'] ?? {},
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}