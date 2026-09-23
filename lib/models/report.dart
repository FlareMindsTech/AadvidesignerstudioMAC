// Course Performance Report Model
class CoursePerformanceReport {
  final List<CoursePerformance> courses;

  CoursePerformanceReport({required this.courses});

  factory CoursePerformanceReport.fromJson(Map<String, dynamic> json) {
    List<CoursePerformance> coursesList = [];
    if (json['courses'] != null) {
      coursesList = (json['courses'] as List)
          .map((c) => CoursePerformance.fromJson(c))
          .toList();
    }
    return CoursePerformanceReport(courses: coursesList);
  }
}

class CoursePerformance {
  final String? courseId;
  final String? courseTitle;
  final int totalStudents;
  final double averageCompletionRate;

  CoursePerformance({
    this.courseId,
    this.courseTitle,
    required this.totalStudents,
    required this.averageCompletionRate,
  });

  factory CoursePerformance.fromJson(Map<String, dynamic> json) {
    return CoursePerformance(
      courseId: json['courseId'] ?? json['_id'] ?? json['course']?['_id'],
      courseTitle: json['courseTitle'] ??
          json['title'] ??
          json['course']?['title'] ??
          'Unknown Course',
      totalStudents: json['totalStudents'] ?? json['studentCount'] ?? 0,
      averageCompletionRate:
          (json['averageCompletionRate'] ?? json['completionRate'] ?? 0.0)
              .toDouble(),
    );
  }
}

// Student Activity Report Model
class StudentActivityReport {
  final int totalStudents;
  final int activeInLast7Days;
  final int inactiveStudents;
  final int totalLessonsCompleted;

  StudentActivityReport({
    required this.totalStudents,
    required this.activeInLast7Days,
    required this.inactiveStudents,
    required this.totalLessonsCompleted,
  });

  factory StudentActivityReport.fromJson(Map<String, dynamic> json) {
    return StudentActivityReport(
      totalStudents: json['totalStudents'] ?? json['total'] ?? 0,
      activeInLast7Days: json['activeStudentsLast7Days'] ??
          json['activeInLast7Days'] ??
          json['activeStudents'] ??
          0,
      inactiveStudents: json['inactiveStudents'] ?? 0,
      totalLessonsCompleted: json['totalLessonsCompleted'] ??
          json['lessonsCompleted'] ??
          0,
    );
  }
}

// Quiz Performance Report Model
class QuizPerformanceReport {
  final List<QuizPerformance> quizzes;

  QuizPerformanceReport({required this.quizzes});

  factory QuizPerformanceReport.fromJson(Map<String, dynamic> json) {
    List<QuizPerformance> quizzesList = [];
    if (json['quizzes'] != null) {
      quizzesList = (json['quizzes'] as List)
          .map((q) => QuizPerformance.fromJson(q))
          .toList();
    }
    return QuizPerformanceReport(quizzes: quizzesList);
  }
}

class QuizPerformance {
  final String? quizId;
  final String? quizTitle;
  final double averageScore;
  final int highestScore;
  final int lowestScore;
  final int totalAttempts;

  QuizPerformance({
    this.quizId,
    this.quizTitle,
    required this.averageScore,
    required this.highestScore,
    required this.lowestScore,
    required this.totalAttempts,
  });

  factory QuizPerformance.fromJson(Map<String, dynamic> json) {
    return QuizPerformance(
      quizId: json['quizId'] ?? json['_id'] ?? json['quiz']?['_id'],
      quizTitle: json['quizTitle'] ??
          json['title'] ??
          json['quiz']?['title'] ??
          'Unknown Quiz',
      averageScore:
          (json['averageScore'] ?? json['avgScore'] ?? 0.0).toDouble(),
      highestScore: json['highestScore'] ?? json['maxScore'] ?? 0,
      lowestScore: json['lowestScore'] ?? json['minScore'] ?? 0,
      totalAttempts: json['totalAttempts'] ?? json['attempts'] ?? 0,
    );
  }
}

