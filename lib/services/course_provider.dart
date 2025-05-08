import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data models/course_model.dart';
import 'base_provider.dart';

class CourseProvider extends BaseProvider {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Course> _courses = [];
  bool _isLoading = false;
  String? _error;
  Course? _currentCourse;
  Lesson? _currentLesson;

  // Getters
  List<Course> get courses => _courses;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Course? get currentCourse => _currentCourse;
  Lesson? get currentLesson => _currentLesson;

  // Fetch all courses
  Future<void> fetchCourses() async {
    if (_auth.currentUser == null) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final userId = _auth.currentUser!.uid;
      final coursesSnapshot = await _firestore.collection('courses').get();

      final List<Course> loadedCourses = [];

      for (var courseDoc in coursesSnapshot.docs) {
        // Get user progress for this course
        final userProgressDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('courseProgress')
            .doc(courseDoc.id)
            .get();

        // Gets lessons for course
        final lessonsSnapshot = await _firestore
            .collection('courses')
            .doc(courseDoc.id)
            .collection('lessons')
            .orderBy('order')
            .get();

        final List<Lesson> lessons = [];

        for (var lessonDoc in lessonsSnapshot.docs) {
          // Gets quizzes for lesson
          final quizzesSnapshot = await _firestore
              .collection('courses')
              .doc(courseDoc.id)
              .collection('lessons')
              .doc(lessonDoc.id)
              .collection('quizzes')
              .get();

          final List<Quiz> quizzes = quizzesSnapshot.docs
              .map((quizDoc) => Quiz.fromFirestore(quizDoc.data(), quizDoc.id))
              .toList();

          // Check if lesson is completed in user progress
          bool isLessonCompleted = false;
          if (userProgressDoc.exists) {
            final completedLessons = List<String>.from(
                userProgressDoc.data()?['completedLessons'] ?? []);
            isLessonCompleted = completedLessons.contains(lessonDoc.id);
          }

          // Create lesson with completion status
          final lessonData = lessonDoc.data();
          lessons.add(Lesson.fromFirestore(
            {...lessonData, 'isCompleted': isLessonCompleted},
            lessonDoc.id,
            quizzes,
          ));
        }

        int completedLessonsCount = lessons.where((l) => l.isCompleted).length;
        double progress =
            lessons.isEmpty ? 0.0 : completedLessonsCount / lessons.length;

        final courseData = courseDoc.data();
        loadedCourses.add(Course.fromFirestore(
          {
            ...courseData,
            'completedLessons': completedLessonsCount,
            'progress': progress,
            'lastAccessedAt': (userProgressDoc.exists &&
                    userProgressDoc.data()?['lastAccessedAt'] != null)
                ? userProgressDoc.data()!['lastAccessedAt']
                : DateTime.now(),
          },
          courseDoc.id,
          lessons,
        ));
      }

      _courses = loadedCourses;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  // Set current course and update last accessed timestamp
  Future<void> setCurrentCourse(Course course) async {
    if (_auth.currentUser == null) return;

    _currentCourse = course;
    _currentLesson = null;
    notifyListeners();

    try {
      final userId = _auth.currentUser!.uid;
      final timestamp = Timestamp.now();

      // Update last accessed timestamp in user's course progress
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('courseProgress')
          .doc(course.id)
          .set({
        'lastAccessedAt': timestamp,
      }, SetOptions(merge: true));

      // Update local course object
      _currentCourse = _currentCourse!.copyWith(
        lastAccessedAt: timestamp.toDate(),
      );

      // Update in courses list
      final index = _courses.indexWhere((c) => c.id == course.id);
      if (index != -1) {
        _courses[index] = _currentCourse!;
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Set current lesson
  void setCurrentLesson(Lesson lesson) {
    _currentLesson = lesson;
    notifyListeners();
  }

  // Mark lesson as completed
  Future<void> completeLesson(Lesson lesson) async {
    if (_auth.currentUser == null || _currentCourse == null) return;

    try {
      final userId = _auth.currentUser!.uid;

      // Update in Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('courseProgress')
          .doc(_currentCourse!.id)
          .set({
        'completedLessons': FieldValue.arrayUnion([lesson.id]),
      }, SetOptions(merge: true));

      // Update local lesson
      final updatedLesson = lesson.copyWith(isCompleted: true);

      // Update in current course
      if (_currentCourse != null) {
        final lessonIndex =
            _currentCourse!.lessons.indexWhere((l) => l.id == lesson.id);
        if (lessonIndex != -1) {
          final updatedLessons = List<Lesson>.from(_currentCourse!.lessons);
          updatedLessons[lessonIndex] = updatedLesson;

          // Calculate new progress
          final completedCount =
              updatedLessons.where((l) => l.isCompleted).length;
          final progress = updatedLessons.isEmpty
              ? 0.0
              : completedCount / updatedLessons.length;

          _currentCourse = _currentCourse!.copyWith(
            lessons: updatedLessons,
            completedLessons: completedCount,
            progress: progress,
          );

          // Update in courses list
          final courseIndex =
              _courses.indexWhere((c) => c.id == _currentCourse!.id);
          if (courseIndex != -1) {
            _courses[courseIndex] = _currentCourse!;
          }
        }
      }

      // Update current lesson if it's the same
      if (_currentLesson?.id == lesson.id) {
        _currentLesson = updatedLesson;
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Complete a quiz
  Future<void> completeQuiz(Quiz quiz) async {
    if (_auth.currentUser == null ||
        _currentCourse == null ||
        _currentLesson == null) {
      return;
    }

    try {
      final userId = _auth.currentUser!.uid;

      // Update in Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('courseProgress')
          .doc(_currentCourse!.id)
          .collection('quizProgress')
          .doc(quiz.id)
          .set({
        'isCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Update local quiz
      if (_currentLesson != null && _currentLesson!.quizzes != null) {
        final quizIndex =
            _currentLesson!.quizzes!.indexWhere((q) => q.id == quiz.id);
        if (quizIndex != -1) {
          final updatedQuizzes = List<Quiz>.from(_currentLesson!.quizzes!);
          updatedQuizzes[quizIndex] = quiz.copyWith(isCompleted: true);

          _currentLesson = _currentLesson!.copyWith(quizzes: updatedQuizzes);

          // Update in current course
          if (_currentCourse != null) {
            final lessonIndex = _currentCourse!.lessons
                .indexWhere((l) => l.id == _currentLesson!.id);
            if (lessonIndex != -1) {
              final updatedLessons = List<Lesson>.from(_currentCourse!.lessons);
              updatedLessons[lessonIndex] = _currentLesson!;

              _currentCourse =
                  _currentCourse!.copyWith(lessons: updatedLessons);

              // Update in courses list
              final courseIndex =
                  _courses.indexWhere((c) => c.id == _currentCourse!.id);
              if (courseIndex != -1) {
                _courses[courseIndex] = _currentCourse!;
              }
            }
          }
        }
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Reset provider state
  void reset() {
    _courses = [];
    _currentCourse = null;
    _currentLesson = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> loadCourses() async {
    await fetchCourses();
  }

  @override
  Future<void> initialize() async {
    await loadCourses();
  }
}
