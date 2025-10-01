class TabFolder {
  final String id;
  String name;
  String? color; // Optional color for visual distinction
  int order; // For sorting folders
  DateTime createdAt;

  TabFolder({
    required this.id,
    required this.name,
    this.color,
    required this.order,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert TabFolder to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'folder_order': order,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Create TabFolder from database Map
  static TabFolder fromMap(Map<String, dynamic> map) {
    return TabFolder(
      id: map['id'] as String,
      name: map['name'] as String,
      color: map['color'] as String?,
      order: map['folder_order'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // Create a copy of this TabFolder with updated values
  TabFolder copyWith({
    String? name,
    String? color,
    int? order,
  }) {
    return TabFolder(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      order: order ?? this.order,
      createdAt: createdAt,
    );
  }
}
