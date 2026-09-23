import 'question.dart';

class Quiz {
  final String? id;
  final String moduleId;
  final String title;
  final List<Question> questions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Quiz({
    this.id,
    required this.moduleId,
    required this.title,
    required this.questions,
    this.createdAt,
    this.updatedAt,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    // Handle module/subModule field - can be a string ID, an object with _id, or null
    String moduleId = '';
    if (json['moduleId'] != null) {
      moduleId = json['moduleId'].toString();
    } else if (json['subModule'] != null) {
      // Handle subModule field (for quizzes associated with submodules)
      if (json['subModule'] is String) {
        moduleId = json['subModule'];
      } else if (json['subModule'] is Map) {
        moduleId = json['subModule']['_id']?.toString() ?? '';
      }
    } else if (json['module'] != null) {
      if (json['module'] is String) {
        moduleId = json['module'];
      } else if (json['module'] is Map) {
        moduleId = json['module']['_id']?.toString() ?? '';
      }
    }

    return Quiz(
      id: json['_id'] ?? json['id'],
      moduleId: moduleId,
      title: json['title'] ?? '',
      questions: json['questions'] != null
          ? (json['questions'] as List)
              .map((q) => Question.fromJson(q))
              .toList()
          : [],
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
      'questions': questions.map((q) => q.toJson()).toList(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  Quiz copyWith({
    String? id,
    String? moduleId,
    String? title,
    List<Question>? questions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Quiz(
      id: id ?? this.id,
      moduleId: moduleId ?? this.moduleId,
      title: title ?? this.title,
      questions: questions ?? this.questions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int get totalMarks {
    return questions.fold(0, (sum, question) => sum + question.marks);
  }

  int get totalQuestions {
    return questions.length;
  }
}

