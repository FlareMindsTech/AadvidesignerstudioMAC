class Lesson {
  final String? id;
  final String moduleId;
  final String title;
  final String? description;
  final String type; // 'video' or 'pdf'
  final String duration;
  final bool isFree;
  final String?
  contentUrl; // Video/PDF URL (may not be in response for security)
  final String? videoProvider;
  final String? bunnyVideoId;
  final String? bunnyLibraryId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Lesson({
    this.id,
    required this.moduleId,
    required this.title,
    this.description,
    required this.type,
    required this.duration,
    required this.isFree,
    this.contentUrl,
    this.videoProvider,
    this.bunnyVideoId,
    this.bunnyLibraryId,
    this.createdAt,
    this.updatedAt,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    // Handle module field - can be a string ID, an object with _id, or null
    String moduleId = '';
    if (json['moduleId'] != null) {
      moduleId = json['moduleId'].toString();
    } else if (json['module'] != null) {
      if (json['module'] is String) {
        moduleId = json['module'];
      } else if (json['module'] is Map) {
        moduleId = json['module']['_id']?.toString() ?? '';
      }
    }

    // Handle duration - can be int, double (seconds), or String
    String durationStr = '';
    if (json['duration'] != null) {
      if (json['duration'] is num) {
        final numValue = (json['duration'] as num).toInt();
        if (numValue > 0) {
          final hours = numValue ~/ 3600;
          final minutes = (numValue % 3600) ~/ 60;
          final seconds = numValue % 60;

          if (hours > 0) {
            durationStr =
                '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
          } else {
            durationStr = '$minutes:${seconds.toString().padLeft(2, '0')}';
          }
        }
      } else if (json['duration'] is String) {
        durationStr = json['duration'];
      } else {
        durationStr = json['duration'].toString();
      }
    }

    return Lesson(
      id: json['_id'] ?? json['id'],
      moduleId: moduleId,
      title: json['title'] ?? '',
      description: json['description'],
      type: json['type'] ?? 'video',
      duration: durationStr,
      isFree: json['isFree'] ?? false,
      contentUrl: json['contentUrl'] ?? json['contentFile'],
      videoProvider: json['videoProvider'],
      bunnyVideoId: json['bunnyVideoId'],
      bunnyLibraryId: json['bunnyLibraryId'],
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
      'moduleId': moduleId,
      'title': title,
      if (description != null) 'description': description,
      'type': type,
      'duration': duration,
      'isFree': isFree,
      if (contentUrl != null) 'contentUrl': contentUrl,
      if (videoProvider != null) 'videoProvider': videoProvider,
      if (bunnyVideoId != null) 'bunnyVideoId': bunnyVideoId,
      if (bunnyLibraryId != null) 'bunnyLibraryId': bunnyLibraryId,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  Lesson copyWith({
    String? id,
    String? moduleId,
    String? title,
    String? description,
    String? type,
    String? duration,
    bool? isFree,
    String? contentUrl,
    String? videoProvider,
    String? bunnyVideoId,
    String? bunnyLibraryId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Lesson(
      id: id ?? this.id,
      moduleId: moduleId ?? this.moduleId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      isFree: isFree ?? this.isFree,
      contentUrl: contentUrl ?? this.contentUrl,
      videoProvider: videoProvider ?? this.videoProvider,
      bunnyVideoId: bunnyVideoId ?? this.bunnyVideoId,
      bunnyLibraryId: bunnyLibraryId ?? this.bunnyLibraryId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isVideo => type.toLowerCase() == 'video';
  bool get isPdf => type.toLowerCase() == 'pdf';
  bool get isExcel =>
      type.toLowerCase() == 'excel' ||
      type.toLowerCase() == 'xlsx' ||
      type.toLowerCase() == 'xls';
  bool get isImage =>
      type.toLowerCase() == 'image' ||
      type.toLowerCase() == 'img' ||
      (contentUrl != null &&
          (contentUrl!.contains('.jpg') ||
              contentUrl!.contains('.jpeg') ||
              contentUrl!.contains('.png') ||
              contentUrl!.contains('.gif') ||
              contentUrl!.contains('.webp')));
  bool get isText => type.toLowerCase() == 'text';
}
