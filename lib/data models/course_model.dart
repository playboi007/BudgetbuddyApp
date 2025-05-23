import 'package:cloud_firestore/cloud_firestore.dart';

class Course {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final List<Lesson> lessons;
  final int totalLessons;
  final int completedLessons;
  final double progress;
  final DateTime createdAt;
  final DateTime? lastAccessedAt;

  Course({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.lessons,
    required this.totalLessons,
    this.completedLessons = 0,
    this.progress = 0.0,
    required this.createdAt,
    this.lastAccessedAt,
  });

  ///factory constructor to change from firestore to map
  factory Course.fromFirestore(
      Map<String, dynamic> data, String docId, List<Lesson> lessons) {
    // Handle the case where completedLessons could be a string, array, or int
    int completedLessonsCount;
    if (data['completedLessons'] is int) {
      completedLessonsCount = data['completedLessons'];
    } else if (data['completedLessons'] is String) {
      // If it's a string, try to parse it as an int, or default to 0
      completedLessonsCount = int.tryParse(data['completedLessons'] ?? '') ?? 0;
    } else if (data['completedLessons'] is List) {
      // If it's a list (array of completed lesson IDs), count the elements
      completedLessonsCount = (data['completedLessons'] as List).length;
    } else {
      completedLessonsCount = 0;
    }

    // Handle totalLessons similarly
    int totalLessonsCount;
    if (data['totalLessons'] is int) {
      totalLessonsCount = data['totalLessons'];
    } else if (data['totalLessons'] is String) {
      totalLessonsCount = int.tryParse(data['totalLessons'] ?? '') ?? 1;
    } else {
      totalLessonsCount = lessons.isNotEmpty ? lessons.length : 1;
    }

    // Calculate progress safely
    double progressValue =
        totalLessonsCount > 0 ? completedLessonsCount / totalLessonsCount : 0.0;

    return Course(
      id: docId,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      lessons: lessons,
      totalLessons: totalLessonsCount,
      completedLessons: completedLessonsCount,
      progress: progressValue,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastAccessedAt: data['lastAccessedAt'] is Timestamp
          ? (data['lastAccessedAt'] as Timestamp).toDate()
          : null,
    );
  }

  factory Course.fromMap(Map<String, dynamic> data, String docId) {
    List<Lesson> lessonsList = [];
    if (data['lessons'] != null) {
      lessonsList = (data['lessons'] as List).map((lessonData) {
        List<Quiz>? quizzes;
        if (lessonData['quizzes'] != null) {
          quizzes = (lessonData['quizzes'] as List).map((quizData) {
            return Quiz.fromFirestore(quizData as Map<String, dynamic>, quizData['id'] ?? '');
          }).toList();
        }
        return Lesson.fromFirestore(lessonData as Map<String, dynamic>, lessonData['id'] ?? '', quizzes);
      }).toList();
    }

    return Course.fromFirestore(data, docId, lessonsList);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'totalLessons': totalLessons,
      'completedLessons': completedLessons,
      'progress': progress,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastAccessedAt':
          lastAccessedAt != null ? Timestamp.fromDate(lastAccessedAt!) : null,
    };
  }

  Course copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    List<Lesson>? lessons,
    int? totalLessons,
    int? completedLessons,
    double? progress,
    DateTime? createdAt,
    DateTime? lastAccessedAt,
  }) {
    return Course(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      lessons: lessons ?? this.lessons,
      totalLessons: totalLessons ?? this.totalLessons,
      completedLessons: completedLessons ?? this.completedLessons,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    );
  }
}

class Lesson {
  final String id;
  final String title;
  final String content;
  bool isCompleted;
  final int order;
  final List<Quiz>? quizzes;

  Lesson({
    required this.id,
    required this.title,
    required this.content,
    this.isCompleted = false,
    required this.order,
    this.quizzes,
  });

  factory Lesson.fromFirestore(
      Map<String, dynamic> data, String docId, List<Quiz>? quizzes) {
    int orderValue;
    if (data['order'] is int) {
      orderValue = data['order'];
    } else if (data['order'] is String) {
      orderValue = int.tryParse(data['order'] ?? '') ?? 0;
    } else {
      orderValue = 0;
    }

    return Lesson(
      id: docId,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      order: orderValue,
      quizzes: quizzes,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'isCompleted': isCompleted,
      'order': order,
    };
  }

  Lesson copyWith({
    String? id,
    String? title,
    String? content,
    bool? isCompleted,
    int? order,
    List<Quiz>? quizzes,
  }) {
    return Lesson(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      isCompleted: isCompleted ?? this.isCompleted,
      order: order ?? this.order,
      quizzes: quizzes ?? this.quizzes,
    );
  }
}

class Quiz {
  final String id;
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  bool isCompleted;

  Quiz({
    required this.id,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    this.isCompleted = false,
  });

  factory Quiz.fromFirestore(Map<String, dynamic> data, String docId) {
    int correctIndex;
    if (data['correctOptionIndex'] is int) {
      correctIndex = data['correctOptionIndex'];
    } else if (data['correctOptionIndex'] is String) {
      correctIndex = int.tryParse(data['correctOptionIndex'] ?? '') ?? 0;
    } else {
      correctIndex = 0;
    }

    return Quiz(
      id: docId,
      question: data['question'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctOptionIndex: correctIndex,
      isCompleted: data['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'question': question,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'isCompleted': isCompleted,
    };
  }

  Quiz copyWith({
    String? id,
    String? question,
    List<String>? options,
    int? correctOptionIndex,
    bool? isCompleted,
  }) {
    return Quiz(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      correctOptionIndex: correctOptionIndex ?? this.correctOptionIndex,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
