class Project {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String visibility;
  final String? rootFolder;
  final String? shareSlug;
  final String? myRole;
  final DateTime createdAt;
  final DateTime updatedAt;

  Project({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    required this.visibility,
    this.rootFolder,
    this.shareSlug,
    this.myRole,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isViewerOnly => myRole == 'viewer';

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id']?.toString() ?? '',
      ownerId: json['owner_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      visibility: json['visibility']?.toString() ?? 'private',
      rootFolder: json['root_folder']?.toString(),
      shareSlug: json['share_slug']?.toString(),
      myRole: json['my_role']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
