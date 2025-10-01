class SmartNote {
  final String id;
  final String content;
  final String? sourceUrl;
  final String? sourceTitle;
  final DateTime createdAt;
  final DateTime updatedAt;

  SmartNote({
    required this.id,
    required this.content,
    this.sourceUrl,
    this.sourceTitle,
    required this.createdAt,
    required this.updatedAt,
  });

  SmartNote copyWith({
    String? id,
    String? content,
    String? sourceUrl,
    String? sourceTitle,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SmartNote(
      id: id ?? this.id,
      content: content ?? this.content,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceTitle: sourceTitle ?? this.sourceTitle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'source_url': sourceUrl,
      'source_title': sourceTitle,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SmartNote.fromJson(Map<String, dynamic> json) {
    return SmartNote(
      id: json['id'],
      content: json['content'],
      sourceUrl: json['source_url'],
      sourceTitle: json['source_title'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  factory SmartNote.create({
    required String content,
    String? sourceUrl,
    String? sourceTitle,
  }) {
    final now = DateTime.now();
    return SmartNote(
      id: 'note_${now.millisecondsSinceEpoch}_${content.hashCode}',
      content: content,
      sourceUrl: sourceUrl,
      sourceTitle: sourceTitle,
      createdAt: now,
      updatedAt: now,
    );
  }
}
