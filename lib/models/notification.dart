class AppNotification {
  final String? id;
  final String? title;
  final String? message;
  final bool read;
  final String? type; // 'announcement' or 'notification'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AppNotification({
    this.id,
    this.title,
    this.message,
    required this.read,
    this.type,
    this.createdAt,
    this.updatedAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['_id'] ?? json['id'],
      title: json['title'] ?? '',
      message: json['message'] ?? json['content'] ?? '',
      read: json['read'] ?? false,
      type: json['type'] ?? 'notification',
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
      if (title != null) 'title': title,
      if (message != null) 'message': message,
      'read': read,
      if (type != null) 'type': type,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    bool? read,
    String? type,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      read: read ?? this.read,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

