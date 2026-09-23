class ApiConfig {
  // ⚡ TOGGLE THIS: Set to 'true' for Local Backend, 'false' for Vercel Production
  static const bool isLocal = false;

  // Base URL for all API endpoints
  static const String baseUrl = isLocal 
      ? 'http://10.212.13.17:5000/api' // <-- Your Local IP (Replace if it changes)
      : 'https://meetapp-sigma.vercel.app/api';
  // Auth endpoints
  static const String authBaseUrl = '$baseUrl/auth';
  static const String loginEndpoint = '$authBaseUrl/login';
  static const String registerEndpoint = '$authBaseUrl/register';
  static const String logoutEndpoint = '$authBaseUrl/logout';
  static const String refreshTokenEndpoint = '$authBaseUrl/refresh-token';
  static const String requestOtpEndpoint = '$authBaseUrl/request-otp';
  static const String verifyOtpEndpoint = '$authBaseUrl/verify-otp';

  // Meeting endpoints
  static const String meetingBaseUrl =
      '$baseUrl/meetings'; // POST create meeting (Admin/Owner Token)
  static const String listMeetingsEndpoint = '$baseUrl/auth/listmeeting';
  static const String getAllMeetingsEndpoint =
      '$baseUrl/meetings'; // GET all meetings (Owner/Admin Token)
  static const String getMyMeetingsEndpoint =
      '$baseUrl/meetings/my-meetings'; // GET my meetings (Student Token)
  static String joinMeetingEndpoint(String meetingId) =>
      '$baseUrl/meetings/join/$meetingId'; // POST join meeting (Student Token)

  // Conference endpoints
  static const String conferenceBaseUrl = '$baseUrl/conferences';

  // Event endpoints
  static const String eventBaseUrl = '$baseUrl/events';

  // Launch endpoints
  static const String launchBaseUrl = '$baseUrl/launches';

  // Users endpoints
  static const String usersBaseUrl = '$baseUrl/auth';
  static const String createAdminEndpoint = '$baseUrl/auth/owner/create-admin';
  static const String createStudentEndpoint = '$baseUrl/auth/create-student';
  static const String getUsersEndpoint = '$usersBaseUrl';
  static const String deleteAccountEndpoint =
      '$baseUrl/user/delete-account'; // DELETE current user account (User Token)
  static const String studentProfileEndpoint =
      '$baseUrl/student/profile'; // Legacy
  static const String userProfileEndpoint =
      '$baseUrl/user/profile'; // GET/PUT user profile (User Token)

  // Admin - Student Management endpoints
  static const String adminCreateStudentEndpoint =
      '$baseUrl/admin/create-student'; // POST create student (Admin/Owner Token)
  static const String adminGetAllStudentsEndpoint =
      '$baseUrl/admin/students'; // GET all students (Admin/Owner Token)
  static String adminGetStudentDetailEndpoint(String studentId) =>
      '$baseUrl/admin/students/$studentId'; // GET student detail (Admin/Owner Token)
  static String adminUpdateStudentEndpoint(String studentId) =>
      '$baseUrl/admin/update-students/$studentId'; // PUT update student with photo (Admin/Owner Token)
  static String adminDeactivateStudentEndpoint(String studentId) =>
      '$baseUrl/admin/students/$studentId/deactivate'; // POST deactivate student (Admin/Owner Token)
  static String adminDeleteStudentEndpoint(String studentId) =>
      '$baseUrl/admin/students/$studentId/delete'; // DELETE student (Admin/Owner Token)

  // Owner - Admin Management endpoints
  static const String ownerCreateAdminEndpoint =
      '$baseUrl/create-admin'; // POST create admin with photo (Owner Token)
  // static const String ownerGetAllAdminsEndpoint = '$baseUrl/owner/get-admins'; // GET all admins (Owner Token)
  static const String getAllAdminsEndpoint =
      '$baseUrl/get-admins'; // GET all admins (Admin/Owner Token)
  static String ownerUpdateAdminEndpoint(String adminId) =>
      '$baseUrl/update-admins/$adminId'; // PUT update admin with photo (Owner Token)
  static String ownerDeleteAdminEndpoint(String adminId) =>
      '$baseUrl/delete-admins/$adminId'; // DELETE admin (Owner Token)

  // Course endpoints
  static const String courseBaseUrl = '$baseUrl/admin/courses';
  static const String createCourseEndpoint = '$courseBaseUrl/create';
  static const String getAllCoursesEndpoint =
      '$baseUrl/courses'; // GET all public courses (No Auth)
  static String getSingleCourseEndpoint(String courseId) =>
      '$baseUrl/courses/$courseId'; // GET single course details (No Auth)
  static String updateCourseEndpoint(String courseId) =>
      '$baseUrl/admin/courses/$courseId/update';
  static String deleteCourseEndpoint(String courseId) =>
      '$baseUrl/admin/courses/$courseId/delete';
  static String getCourseModulesEndpoint(String courseId) =>
      '$baseUrl/courses/$courseId/modules'; // GET course modules (No Auth)
  static String enrollCourseEndpoint(String courseId) =>
      '$baseUrl/courses/$courseId/enroll'; // POST enroll student (Student Token)
  static String getEnrolledStudentsEndpoint(String courseId) =>
      '$baseUrl/admin/courses/$courseId/students'; // GET enrolled students (Admin Token)
  static const String manualEnrollEndpoint = '$baseUrl/admin/manual-enroll';

  // Module endpoints
  static String addModuleEndpoint(String courseId) =>
      '$baseUrl/admin/courses/$courseId/modules'; // POST add module (Admin Token)
  static String updateModuleEndpoint(String moduleId) =>
      '$baseUrl/admin/modules/$moduleId/update'; // PUT update module (Admin Token)
  static String deleteModuleEndpoint(String moduleId) =>
      '$baseUrl/admin/modules/$moduleId/delete'; // DELETE module (Admin Token)

  // SubModule (Sub-Topic) endpoints
  static String addSubModuleEndpoint(String moduleId) =>
      '$baseUrl/admin/modules/$moduleId/submodules'; // POST create submodule (Admin Token)
  static String updateSubModuleEndpoint(String subModuleId) =>
      '$baseUrl/admin/submodules/$subModuleId/update'; // PUT update submodule (Admin Token)

  static String deleteSubModuleEndpoint(String subModuleId) =>
      '$baseUrl/admin/submodules/$subModuleId/delete'; // DELETE submodule (Admin Token)

  // Quiz endpoints (Admin)
  static const String createQuizEndpoint =
      '$baseUrl/admin/quiz/create'; // POST create quiz (Admin Token)
  static const String getAllQuizzesEndpoint =
      '$baseUrl/admin/quizzes'; // GET all quizzes (Admin Token)
  static String addQuestionsToQuizEndpoint(String quizId) =>
      '$baseUrl/admin/quiz/$quizId/questions'; // POST add questions (Admin Token)
  static String updateQuizEndpoint(String quizId) =>
      '$baseUrl/admin/quiz/$quizId/update'; // PUT update quiz (Admin Token)
  static String deleteQuizEndpoint(String quizId) =>
      '$baseUrl/admin/quiz/$quizId/delete'; // DELETE quiz (Admin Token)

  // Quiz endpoints (Student)
  static String getModuleQuizEndpoint(String moduleId) =>
      '$baseUrl/module/$moduleId/quiz'; // GET quiz for module (Student Token) - without correct answers
  static String submitQuizEndpoint(String quizId) =>
      '$baseUrl/quiz/$quizId/submit'; // POST submit quiz answers (Student Token)
  static String getQuizResultEndpoint(String quizId) =>
      '$baseUrl/quiz/$quizId/result'; // GET quiz result (Student Token)

  // Lesson endpoints
  static String getModuleLessonsEndpoint(String submoduleId) =>
      '$baseUrl/submodules/$submoduleId/lessons'; // GET all lessons in submodule (Student Token)
  static const String createLessonEndpoint =
      '$baseUrl/admin/lessons/create'; // POST create lesson (Admin Token)
  static String updateLessonEndpoint(String lessonId) =>
      '$baseUrl/admin/lessons/$lessonId/update'; // PUT update lesson (Admin Token)
  static String deleteLessonEndpoint(String lessonId) =>
      '$baseUrl/admin/lessons/$lessonId/delete'; // DELETE lesson (Admin Token)
  static const String uploadLessonEndpoint =
      '$baseUrl/admin/lesson/upload'; // POST upload resource/file (Admin Token) - Standalone utility
  static const String bunnyStreamUploadEndpoint =
      '$baseUrl/admin/lesson/bunny-stream-upload';

  // Reports endpoints (Admin)
  static const String coursePerformanceReportEndpoint =
      '$baseUrl/admin/reports/course-performance'; // GET course performance report (Admin Token)
  static const String studentActivityReportEndpoint =
      '$baseUrl/admin/reports/student-activity'; // GET student activity report (Admin Token)
  static const String quizPerformanceReportEndpoint =
      '$baseUrl/admin/reports/quiz-performance'; // GET quiz performance report (Admin Token)

  // Announcements endpoints (Admin)
  static const String createAnnouncementEndpoint =
      '$baseUrl/admin/announcement/create'; // POST create announcement (Admin Token)
  static const String listAnnouncementsEndpoint =
      '$baseUrl/admin/announcement/list'; // GET list all announcements (Admin Token)
  static String deleteAnnouncementEndpoint(String announcementId) =>
      '$baseUrl/admin/announcement/delete/$announcementId'; // DELETE announcement (Admin Token)

  // Notifications endpoints (Student)
  static const String getNotificationsEndpoint =
      '$baseUrl/notifications'; // GET my notifications (Student Token)
  static String markNotificationReadEndpoint(String notificationId) =>
      '$baseUrl/notifications/$notificationId/mark-read'; // POST mark notification as read (Student Token)

  // Payment endpoints (Student)
  static const String initiatePaymentEndpoint =
      '$baseUrl/payment/initiate'; // POST initiate payment (Student Token)
  static const String verifyPaymentEndpoint =
      '$baseUrl/payment/verify'; // POST verify payment (Student Token)
  static const String verifySubscriptionEndpoint =
      '$baseUrl/payment/verify-subscription'; // POST verify subscription (Student Token)
  static const String subscriptionStatusEndpoint =
      '$baseUrl/subscription/status'; // GET subscription status (Student Token)
  static const String getPaymentHistoryEndpoint =
      '$baseUrl/payments/history'; // GET payment history (Student Token)

  // Payment Management endpoints (Admin)
  static const String getAllPaymentsEndpoint =
      '$baseUrl/admin/payments'; // GET all one-time payments (Admin Token)
  static const String getAllSubscriptionsEndpoint =
      '$baseUrl/admin/subscriptions'; // GET all subscriptions (Admin Token)
  static String cancelSubscriptionEndpoint(String subscriptionId) =>
      '$baseUrl/admin/subscriptions/$subscriptionId/cancel'; // POST cancel subscription (Admin Token)
  static String getStudentPaymentHistoryEndpoint(String studentId) =>
      '$baseUrl/admin/payments/student/$studentId'; // GET student payment history (Admin Token)

  // CMS endpoints (Public - No Auth)
  static const String getAboutUsEndpoint =
      '$baseUrl/cms/about-us'; // GET about-us page (No Auth)
  static const String getPrivacyPolicyEndpoint =
      '$baseUrl/cms/privacy-policy'; // GET privacy-policy page (No Auth)
  static const String getTermsEndpoint =
      '$baseUrl/cms/terms'; // GET terms page (No Auth)

  // CMS Management endpoints (Admin)
  static const String getAllCmsPagesEndpoint =
      '$baseUrl/admin/cms/pages'; // GET all CMS pages (Admin Token)
  static String updateCmsPageEndpoint(String pageId) =>
      '$baseUrl/admin/cms/page/$pageId'; // PUT update CMS page (Admin Token)

  // Progress endpoints (Student)
  static String markLessonCompleteEndpoint(String lessonId) =>
      '$baseUrl/progress/lessons/$lessonId'; // POST mark lesson as complete (Student Token)
  static const String getCourseProgressEndpoint =
      '$baseUrl/progress/courses'; // GET all course progress (Student Token)
  static String getModuleProgressEndpoint(String moduleId) =>
      '$baseUrl/progress/modules/$moduleId'; // GET module progress (Student Token)

  // Chat/Conversations endpoints (Admin/Owner)
  static const String getAllConversationsEndpoint =
      '$baseUrl/conversations'; // GET all conversations (Admin/Owner Token)
  static const String createSingleChatEndpoint =
      '$baseUrl/conversation/single'; // POST create single chat (Admin Token)
  static const String createGroupChatEndpoint =
      '$baseUrl/conversation/group'; // POST create group chat (Admin Token)
  static String manageGroupUserEndpoint(String conversationId) =>
      '$baseUrl/conversation/$conversationId/manage-user'; // POST manage group user (Admin Token)
  static String updateGroupDetailsEndpoint(String conversationId) =>
      '$baseUrl/conversation/$conversationId/update'; // PUT update group details (Admin Token)
  static String deleteConversationEndpoint(String conversationId) =>
      '$baseUrl/conversations/$conversationId'; // DELETE conversation (Admin/Owner Token)

  // Message endpoints (Both Admin/Owner and Student)
  static const String sendMessageEndpoint =
      '$baseUrl/message'; // POST send message (Both Token)
  static const String getMessagesEndpoint =
      '$baseUrl/messages'; // GET get messages (Both Token)
  static const String markMessageReadEndpoint = '$baseUrl/message/read';

  // Request timeout duration
  static const Duration timeout = Duration(seconds: 30);

  // Headers
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Map<String, String> getAuthHeaders(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  static Map<String, String> getAuthHeadersMultipart(String token) => {
    'Authorization': 'Bearer $token',
  };

  // Helper to sanitize image URLs
  static String getImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    // If it's a full URL (like Cloudinary), ensure it uses https and optimize if possible
    if (url.startsWith('http')) {
      String sanitizedUrl = url.replaceFirst('http://', 'https://');

      // If it's a Cloudinary URL, inject optimization parameters (q_auto, f_jpg)
      // Using f_jpg instead of f_webp because some Cloudinary configs silently
      // upgrade to AVIF, which Flutter's Skia cannot decode on many devices.
      if (sanitizedUrl.contains('res.cloudinary.com')) {
        if (sanitizedUrl.contains(RegExp(r'f_[a-zA-Z0-9]+'))) {
          // Replace any existing format parameter (f_auto, f_avif, f_webp, etc.) with f_jpg
          sanitizedUrl = sanitizedUrl.replaceAll(
            RegExp(r'f_[a-zA-Z0-9]+'),
            'f_jpg',
          );
        } else if (sanitizedUrl.contains('/upload/')) {
          // If no format parameter exists, inject it
          if (!sanitizedUrl.contains('q_auto')) {
            sanitizedUrl = sanitizedUrl.replaceFirst(
              '/upload/',
              '/upload/q_auto,f_jpg/',
            );
          } else {
            sanitizedUrl = sanitizedUrl.replaceFirst(
              '/upload/',
              '/upload/f_jpg,',
            );
          }
        }
      }

      return sanitizedUrl;
    }

    // If it's a relative path, prepend the base Vercel domain
    // Replace any backslashes (Windows) with forward slashes
    final cleanPath = url.replaceAll('\\', '/');
    final formattedPath = cleanPath.startsWith('/') ? cleanPath : '/$cleanPath';

    return 'https://meetapp-sigma.vercel.app$formattedPath';
  }
}
