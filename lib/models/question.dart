class Question {
  final String? id;
  final String questionText;
  final List<String> options;
  final int correctOption; // Index of correct answer (0-based)
  final int marks;

  Question({
    this.id,
    required this.questionText,
    required this.options,
    required this.correctOption,
    required this.marks,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['_id'] ?? json['id'],
      questionText: json['questionText'] ?? '',
      options: json['options'] != null
          ? List<String>.from(json['options'])
          : [],
      correctOption: json['correctOption'] ?? 0,
      marks: json['marks'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'questionText': questionText,
      'options': options,
      'correctOption': correctOption,
      'marks': marks,
    };
  }

  Question copyWith({
    String? id,
    String? questionText,
    List<String>? options,
    int? correctOption,
    int? marks,
  }) {
    return Question(
      id: id ?? this.id,
      questionText: questionText ?? this.questionText,
      options: options ?? this.options,
      correctOption: correctOption ?? this.correctOption,
      marks: marks ?? this.marks,
    );
  }
}

