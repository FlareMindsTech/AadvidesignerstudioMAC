class CmsPage {
  final String? id;
  final String slug;
  final String title;
  final String content;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CmsPage({
    this.id,
    required this.slug,
    required this.title,
    required this.content,
    this.createdAt,
    this.updatedAt,
  });

  factory CmsPage.fromJson(Map<String, dynamic> json) {
    return CmsPage(
      id: json['_id'],
      slug: json['slug'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'slug': slug,
      'title': title,
      'content': content,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'title': title,
      'content': content,
    };
  }
}

class CmsPageListItem {
  final String id;
  final String slug;

  CmsPageListItem({
    required this.id,
    required this.slug,
  });

  factory CmsPageListItem.fromJson(Map<String, dynamic> json) {
    return CmsPageListItem(
      id: json['_id'] ?? '',
      slug: json['slug'] ?? '',
    );
  }
}

