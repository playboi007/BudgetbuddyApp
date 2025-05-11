import 'package:budgetbuddy_app/data%20models/course_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:budgetbuddy_app/services/firebase_service.dart';
import 'base_provider.dart';

class CourseProvider extends BaseProvider {
  static final CourseProvider _instance = CourseProvider._internal();
  factory CourseProvider() => _instance;
  CourseProvider._internal();

  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;
  String? _error;
  List<Course> _courses = [];
  Map<String, Map<String, dynamic>> _courseProgress = {};
  Lesson? _currentLesson;
  Course? _currentCourse;

  @override
  bool get isLoading => _isLoading;
  @override
  String? get error => _error;
  List<Course> get courses => _courses;
  Map<String, Map<String, dynamic>> get courseProgress => _courseProgress;
  Lesson? get currentLesson => _currentLesson;
  Course? get currentCourse => _currentCourse;

  @override
  Future<void> initialize() async {
    await loadCourses();
  }

  Future<void> loadCourses() async {
    if (_isLoading) return;
    _setLoading(true);

    try {
      // Check cache first
      final cached = getCached<List<Course>>('courses', 'all');
      if (cached != null) {
        _courses = cached;
        _setLoading(false);
        notifyListeners();
        return;
      }

      final coursesSnapshot = await _firebaseService.getCourses().get();
      _courses = coursesSnapshot.docs
          .map((doc) =>
              Course.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Cache courses with 15 minute TTL
      cache('courses', 'all', _courses, ttl: const Duration(minutes: 15));

      await _loadCourseProgress();
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error loading courses: $e');
      }
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> _loadCourseProgress() async {
    try {
      // Check cache first
      final cached =
          getCached<Map<String, Map<String, dynamic>>>('courses', 'progress');
      if (cached != null) {
        _courseProgress = cached;
        return;
      }

      final progressSnapshot = await _firebaseService.getCourseProgress().get();

      _courseProgress = Map.fromEntries(
        progressSnapshot.docs.map((doc) => MapEntry(
              doc.id,
              {
                'completed':
                    (doc.data() as Map<String, dynamic>)['completed'] ?? false,
                'lastAccessed':
                    (doc.data() as Map<String, dynamic>)['lastAccessed'],
                'progress':
                    (doc.data() as Map<String, dynamic>)['progress'] ?? 0.0,
              },
            )),
      );

      // Cache progress with 5 minute TTL
      cache('courses', 'progress', _courseProgress,
          ttl: const Duration(minutes: 5));
    } catch (e) {
      if (kDebugMode) {
        print('Error loading course progress: $e');
      }
    }
  }

  Future<void> updateCourseProgress(String courseId, double progress) async {
    try {
      await _firebaseService.updateCourseProgress(courseId, {
        'progress': progress,
        'lastAccessed': FieldValue.serverTimestamp(),
        'completed': progress >= 1.0,
      });

      _courseProgress[courseId] = {
        'progress': progress,
        'lastAccessed': Timestamp.now(),
        'completed': progress >= 1.0,
      };

      // Invalidate progress cache
      clearCache('courses');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error updating course progress: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getCourseDetails(String courseId) async {
    try {
      // Check cache first
      final cached =
          getCached<Map<String, dynamic>>('courses', 'details_$courseId');
      if (cached != null) return cached;

      final courseDoc = await _firebaseService.getCourse(courseId).get();
      if (!courseDoc.exists) return null;

      final courseData = {
        'id': courseDoc.id,
        ...courseDoc.data() as Map<String, dynamic>,
      };

      // Cache course details with 15 minute TTL
      cache('courses', 'details_$courseId', courseData,
          ttl: const Duration(minutes: 15));

      return courseData;
    } catch (e) {
      _error = e.toString();
      return null;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
  }

  void setCurrentLesson(Lesson lesson) {
    _currentLesson = lesson;
    notifyListeners();
  }

  void setCurrentCourse(Course course) {
    _currentCourse = course;
    notifyListeners();
  }

  void completeLesson(Lesson lesson) {
    lesson.isCompleted = true;
    notifyListeners();
  }

  void completeQuiz(Quiz quiz) {
    quiz.isCompleted = true;
    notifyListeners();
  }
}
