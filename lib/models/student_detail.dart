import 'user.dart';
import 'course.dart';

class SubscribedCourse {
  final String id;
  final Course course;
  final DateTime subscribedAt;
  final DateTime expiresAt;

  SubscribedCourse({
    required this.id,
    required this.course,
    required this.subscribedAt,
    required this.expiresAt,
  });

  factory SubscribedCourse.fromJson(Map<String, dynamic> json) {
    // Handle the nested courseId structure from API
    final courseData = json['courseId'] ?? json['course'] ?? {};
    
    // Create a Course object from the nested structure
    // The API may only return partial course data (id, title, price, thumbnail)
    final course = Course(
      id: courseData['_id']?.toString(),
      title: courseData['title']?.toString() ?? 'Unknown Course',
      description: courseData['description']?.toString() ?? '',
      category: courseData['category']?.toString() ?? '',
      price: (courseData['price'] is num) ? (courseData['price'] as num).toDouble() : 0.0,
      thumbnail: courseData['thumbnail']?.toString(),
      duration: courseData['duration']?.toString() ?? '',
      durationinDays: courseData['durationInDays'] ?? courseData['durationinDays'],
      isLiveCourse: courseData['isLiveCourse'] ?? false,
    );
    
    return SubscribedCourse(
      id: json['_id'] ?? '',
      course: course,
      subscribedAt: json['subscribedAt'] != null
          ? DateTime.parse(json['subscribedAt'])
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : DateTime.now(),
    );
  }

  bool get isLifetimeAccess {
    // Consider lifetime if expires more than 100 years from now
    return expiresAt.isAfter(DateTime.now().add(const Duration(days: 36500)));
  }

  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }
}

class StudentDetail {
  final User user;
  final List<SubscribedCourse> subscribedCourses;
  final List<dynamic> progressReports;

  StudentDetail({
    required this.user,
    required this.subscribedCourses,
    required this.progressReports,
  });

  factory StudentDetail.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] ?? json;
    
    List<SubscribedCourse> courses = [];
    if (profile['subscribedCourses'] != null) {
      courses = (profile['subscribedCourses'] as List)
          .where((courseInfo) {
            // If the course was deleted from the database, the backend might return null for courseId/course
            final hasCourseData = courseInfo['courseId'] != null || courseInfo['course'] != null;
            return hasCourseData;
          })
          .map((course) => SubscribedCourse.fromJson(course))
          .toList();
    }

    return StudentDetail(
      user: User.fromJson(profile),
      subscribedCourses: courses,
      progressReports: profile['progressReports'] ?? [],
    );
  }
}

