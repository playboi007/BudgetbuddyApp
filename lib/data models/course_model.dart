import 'package:cloud_firestore/cloud_firestore.dart';

class Course {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final int totalLessons;
  final int completedLessons;
  final double progress;
  final DateTime? lastAccessedAt;
  final List<dynamic> lessons;

  Course({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.totalLessons,
    this.completedLessons = 0,
    this.progress = 0.0,
    this.lastAccessedAt,
    required this.lessons,
  });

  factory Course.fromMap(Map<String, dynamic> map, String id) {
    return Course(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      totalLessons: map['lessons']?.length ?? 0,
      completedLessons: map['completedLessons'] ?? 0,
      progress: (map['progress'] ?? 0.0).toDouble(),
      lastAccessedAt: map['lastAccessedAt'] != null
          ? (map['lastAccessedAt'] as Timestamp).toDate()
          : null,
      lessons: map['lessons'] ?? [],
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
