import 'lesson.dart';
import 'quiz.dart';

class SubModule {
  final String? id;
  final String title;
  final int order;
  final String? moduleId;
  final String? parentSubModuleId; // Added for nesting
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  /// Optional list of lessons when the API returns nested lessons under a submodule
  final List<Lesson>? lessons;
  
  /// Optional list of nested submodules
  List<SubModule>? subModules;
  
  /// Optional quiz associated with this submodule
  final Quiz? quiz;

  SubModule({
    this.id,
    required this.title,
    required this.order,
    this.moduleId,
    this.parentSubModuleId,
    this.createdAt,
    this.updatedAt,
    this.lessons,
    this.subModules,
    this.quiz,
  });

  factory SubModule.fromJson(Map<String, dynamic> json) {
    List<Lesson>? parsedLessons;
    try {
      if (json['lessons'] != null && json['lessons'] is List) {
        parsedLessons = (json['lessons'] as List)
            .map(
              (lessonJson) => Lesson.fromJson(
                Map<String, dynamic>.from(lessonJson as Map),
              ),
            )
            .toList();
      }
    } catch (e) {
      // If lesson parsing fails, just ignore and keep lessons null
    }

    List<SubModule>? parsedSubModules;
    try {
      if (json['subModules'] != null && json['subModules'] is List) {
        parsedSubModules = (json['subModules'] as List)
            .map(
              (subJson) => SubModule.fromJson(
                Map<String, dynamic>.from(subJson as Map),
              ),
            )
            .toList();
      }
    } catch (e) {
      // ignore
    }

    Quiz? parsedQuiz;
    try {
      if (json['quiz'] != null && json['quiz'] is Map) {
        parsedQuiz = Quiz.fromJson(Map<String, dynamic>.from(json['quiz'] as Map));
      }
    } catch (e) {
      // If quiz parsing fails, just ignore and keep quiz null
    }

    return SubModule(
      id: json['_id'] ?? json['id'],
      title: json['title'] ?? '',
      order: json['order'] ?? 0,
      moduleId: json['moduleId'] ?? json['module'],
      parentSubModuleId: json['parentSubModule'] ?? json['parentSubModuleId'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      lessons: parsedLessons,
      subModules: parsedSubModules,
      quiz: parsedQuiz,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'title': title,
      'order': order,
      if (moduleId != null) 'moduleId': moduleId,
      if (parentSubModuleId != null) 'parentSubModule': parentSubModuleId,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (lessons != null) 'lessons': lessons!.map((l) => l.toJson()).toList(),
      if (subModules != null) 'subModules': subModules!.map((s) => s.toJson()).toList(),
      if (quiz != null) 'quiz': quiz!.toJson(),
    };
  }

  SubModule copyWith({
    String? id,
    String? title,
    int? order,
    String? moduleId,
    String? parentSubModuleId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Lesson>? lessons,
    List<SubModule>? subModules,
    Quiz? quiz,
  }) {
    return SubModule(
      id: id ?? this.id,
      title: title ?? this.title,
      order: order ?? this.order,
      moduleId: moduleId ?? this.moduleId,
      parentSubModuleId: parentSubModuleId ?? this.parentSubModuleId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lessons: lessons ?? this.lessons,
      subModules: subModules ?? this.subModules,
      quiz: quiz ?? this.quiz,
    );
  }
}
