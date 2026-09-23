import 'package:flutter/material.dart';
import '../models/meeting.dart';
import '../models/conference.dart';
import '../models/event.dart';
import '../models/launch.dart';
import '../models/course.dart';
import '../services/meeting_service.dart';
import '../services/course_service.dart';

class AppProvider extends ChangeNotifier {
  // Loading states
  bool _isLoadingMeetings = false;
  bool _isLoadingConferences = false;
  bool _isLoadingEvents = false;
  bool _isLoadingLaunches = false;
  bool _isLoadingCourses = false;

  // Data lists
  List<Meeting> _meetings = [];
  List<Conference> _conferences = [];
  List<Event> _events = [];
  List<Launch> _launches = [];
  List<Course> _courses = [];

  // Selected navigation index
  int _selectedIndex = 0;

  // Getters
  bool get isLoadingMeetings => _isLoadingMeetings;
  bool get isLoadingConferences => _isLoadingConferences;
  bool get isLoadingEvents => _isLoadingEvents;
  bool get isLoadingLaunches => _isLoadingLaunches;
  bool get isLoadingCourses => _isLoadingCourses;

  List<Meeting> get meetings => _meetings;
  List<Conference> get conferences => _conferences;
  List<Event> get events => _events;
  List<Launch> get launches => _launches;
  List<Course> get courses => _courses;

  int get selectedIndex => _selectedIndex;

  // Methods
  void setSelectedIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  // Timestamps for smart refresh debounce
  DateTime? _lastMeetingLoadTime;
  DateTime? _lastCourseLoadTime;
  
  static const _cacheDuration = Duration(seconds: 30);

  // Meeting methods
  Future<void> loadMeetings({bool force = false}) async {
    if (_isLoadingMeetings) return;
    
    // Smart refresh debounce
    if (!force && _lastMeetingLoadTime != null) {
      if (DateTime.now().difference(_lastMeetingLoadTime!) < _cacheDuration) {
        return; // Use cached data
      }
    }
    
    _isLoadingMeetings = true;
    notifyListeners();

    try {
      _meetings = await MeetingService.getMeetings();
      _lastMeetingLoadTime = DateTime.now();
      debugPrint('Loaded ${_meetings.length} meetings');
    } catch (e) {
      // Handle error
      debugPrint('Error loading meetings: $e');
    } finally {
      _isLoadingMeetings = false;
      notifyListeners();
    }
  }

  Future<void> loadConferences({bool force = false}) async {
    if (_isLoadingConferences) return;
    
    _isLoadingConferences = true;
    notifyListeners();

    try {
      // Artificial delay removed for performance
      _conferences = []; 
    } catch (e) {
      debugPrint('Error loading conferences: $e');
    } finally {
      _isLoadingConferences = false;
      notifyListeners();
    }
  }

  Future<void> loadEvents({bool force = false}) async {
    if (_isLoadingEvents) return;
    
    _isLoadingEvents = true;
    notifyListeners();

    try {
      // Artificial delay removed for performance
      _events = []; 
    } catch (e) {
      debugPrint('Error loading events: $e');
    } finally {
      _isLoadingEvents = false;
      notifyListeners();
    }
  }

  Future<void> loadLaunches({bool force = false}) async {
    if (_isLoadingLaunches) return;
    
    _isLoadingLaunches = true;
    notifyListeners();

    try {
      // Artificial delay removed for performance
      _launches = []; 
    } catch (e) {
      debugPrint('Error loading launches: $e');
    } finally {
      _isLoadingLaunches = false;
      notifyListeners();
    }
  }

  // Course methods
  Future<void> loadCourses({bool force = false}) async {
    if (_isLoadingCourses) return;
    
    // Smart refresh debounce
    if (!force && _lastCourseLoadTime != null) {
      if (DateTime.now().difference(_lastCourseLoadTime!) < _cacheDuration) {
        return; // Use cached data
      }
    }
    
    _isLoadingCourses = true;
    notifyListeners();

    try {
      _courses = await CourseService.getAllCourses();
      _lastCourseLoadTime = DateTime.now();
      debugPrint('Loaded ${_courses.length} courses');
    } catch (e) {
      // Handle error
      debugPrint('Error loading courses: $e');
    } finally {
      _isLoadingCourses = false;
      notifyListeners();
    }
  }

  // Load all data
  Future<void> loadAllData({bool force = false}) async {
    // Only load what's actually needed in parallel to save time
    await Future.wait([
      loadCourses(force: force),
      // loadConferences(force: force),
      // loadEvents(force: force),
      // loadLaunches(force: force),
    ]);
  }

  // Refresh methods
  Future<void> refreshMeetings() async {
    _meetings.clear();
    await loadMeetings(force: true);
  }

  Future<void> refreshConferences() async {
    _conferences.clear();
    await loadConferences(force: true);
  }

  Future<void> refreshEvents() async {
    _events.clear();
    await loadEvents(force: true);
  }

  Future<void> refreshLaunches() async {
    _launches.clear();
    await loadLaunches(force: true);
  }

  Future<void> refreshCourses() async {
    _courses.clear();
    await loadCourses(force: true);
  }
}
