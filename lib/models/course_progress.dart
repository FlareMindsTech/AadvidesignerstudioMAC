class CourseProgress {
  final String courseId;
  final String courseTitle;
  final String? thumbnail;
  final int percentageCompleted;

  CourseProgress({
    required this.courseId,
    required this.courseTitle,
    this.thumbnail,
    required this.percentageCompleted,
  });

  factory CourseProgress.fromJson(Map<String, dynamic> json) {
    // Handle courseId - can be either a String or a Map
    String courseId = '';
    String courseTitle = '';
    String? thumbnail;
    
    if (json['courseId'] is Map) {
      // Nested format: courseId: {_id: "...", title: "..."}
      final courseIdMap = json['courseId'] as Map<String, dynamic>;
      courseId = courseIdMap['_id'] ?? courseIdMap['id'] ?? '';
      courseTitle = courseIdMap['title'] ?? '';
      thumbnail = courseIdMap['thumbnail'];
    } else if (json['courseId'] is String) {
      // Direct string format: courseId: "6949f9ba30b81c93e7ed83cf"
      courseId = json['courseId'] as String;
      courseTitle = json['title'] ?? json['courseTitle'] ?? '';
      thumbnail = json['thumbnail'];
    } else {
      // Fallback
      courseId = json['_id'] ?? json['id'] ?? '';
      courseTitle = json['title'] ?? json['courseTitle'] ?? '';
      thumbnail = json['thumbnail'];
    }
    
    return CourseProgress(
      courseId: courseId,
      courseTitle: courseTitle,
      thumbnail: thumbnail,
      percentageCompleted: json['percentCompleted'] ?? json['percentageCompleted'] ?? json['percentage'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'courseId': courseId,
      'courseTitle': courseTitle,
      'thumbnail': thumbnail,
      'percentageCompleted': percentageCompleted,
    };
  }
}

class ModuleProgress {
  final String moduleId;
  final String moduleTitle;
  final int completedLessons;
  final int totalLessons;
  final int percentageCompleted;

  ModuleProgress({
    required this.moduleId,
    required this.moduleTitle,
    required this.completedLessons,
    required this.totalLessons,
    required this.percentageCompleted,
  });

  factory ModuleProgress.fromJson(Map<String, dynamic> json) {
    // Handle different API response formats
    String moduleId = '';
    String moduleTitle = '';
    
    if (json['moduleId'] is Map) {
      // Nested format: moduleId: {_id: "...", title: "..."}
      moduleId = json['moduleId']?['_id'] ?? json['moduleId']?['id'] ?? '';
      moduleTitle = json['moduleId']?['title'] ?? '';
    } else if (json['moduleId'] is String) {
      // Direct string format: moduleId: "694612ee79352691286f62f1"
      moduleId = json['moduleId'] ?? '';
      moduleTitle = json['moduleTitle'] ?? json['title'] ?? '';
    } else {
      moduleId = json['_id'] ?? json['id'] ?? '';
      moduleTitle = json['title'] ?? json['moduleTitle'] ?? '';
    }
    
    return ModuleProgress(
      moduleId: moduleId,
      moduleTitle: moduleTitle,
      completedLessons: json['completedCount'] ?? json['completedLessons'] ?? json['completed'] ?? 0,
      totalLessons: json['totalLessons'] ?? json['total'] ?? 0,
      percentageCompleted: json['percentCompleted'] ?? json['percentageCompleted'] ?? json['percentage'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'moduleId': moduleId,
      'moduleTitle': moduleTitle,
      'completedLessons': completedLessons,
      'totalLessons': totalLessons,
      'percentageCompleted': percentageCompleted,
    };
  }
}

