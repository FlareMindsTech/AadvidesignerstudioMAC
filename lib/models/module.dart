import 'lesson.dart';
import 'submodule.dart';

class Module {
  final String? id;
  final String title;
  final int order;
  final String? courseId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Optional list of lessons when the API returns nested lessons under a module.
  /// This is mainly used on the course detail screen to show lessons directly.
  final List<Lesson>? lessons;

  /// Optional list of submodules (sub-topics) when the API returns nested submodules under a module.
  final List<SubModule>? submodules;

  Module({
    this.id,
    required this.title,
    required this.order,
    this.courseId,
    this.createdAt,
    this.updatedAt,
    this.lessons,
    this.submodules,
  });

  factory Module.fromJson(Map<String, dynamic> json) {
    List<Lesson>? parsedLessons;
    try {
      final lessonsData = json['lessons'];
      if (lessonsData is List) {
        parsedLessons = lessonsData
            .map(
              (lessonJson) => Lesson.fromJson(
                Map<String, dynamic>.from(lessonJson as Map),
              ),
            )
            .toList();
      }
    } catch (e) {
      // If lesson parsing fails for any reason, just ignore and keep lessons null
    }

    List<SubModule>? parsedSubmodules;
    try {
      // Handle both 'submodules' and 'subModules' (camelCase from API)
      final submodulesData = json['submodules'] ?? json['subModules'];
      if (submodulesData is List) {
        parsedSubmodules = submodulesData
            .map(
              (submoduleJson) => SubModule.fromJson(
                Map<String, dynamic>.from(submoduleJson as Map),
              ),
            )
            .toList();
      }
    } catch (e) {
      // If submodule parsing fails for any reason, just ignore and keep submodules null
    }

    return Module(
      id: json['_id'] ?? json['id'],
      title: json['title'] ?? '',
      order: json['order'] ?? 0,
      courseId: json['courseId'] ?? json['course'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      lessons: parsedLessons,
      submodules: parsedSubmodules,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'title': title,
      'order': order,
      if (courseId != null) 'courseId': courseId,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (lessons != null) 'lessons': lessons!.map((l) => l.toJson()).toList(),
      if (submodules != null) 'submodules': submodules!.map((s) => s.toJson()).toList(),
    };
  }

  Module copyWith({
    String? id,
    String? title,
    int? order,
    String? courseId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Lesson>? lessons,
    List<SubModule>? submodules,
  }) {
    return Module(
      id: id ?? this.id,
      title: title ?? this.title,
      order: order ?? this.order,
      courseId: courseId ?? this.courseId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lessons: lessons ?? this.lessons,
      submodules: submodules ?? this.submodules,
    );
  }
}

