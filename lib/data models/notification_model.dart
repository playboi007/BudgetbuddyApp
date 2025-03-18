import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String?
      relatedItemId; // ID of related item (e.g., category, transaction)
  final String?
      relatedItemType; // Type of related item (e.g., 'category', 'transaction')

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.relatedItemId,
    this.relatedItemType,
  });

  factory NotificationModel.fromFirestore(
      Map<String, dynamic> data, String docId) {
    return NotificationModel(
      id: docId,
      title: data['title'] ?? 'Notification',
      message: data['message'] ?? '',
      timestamp: data['timestamp'] is Timestamp
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: data['isRead'] ?? false,
      relatedItemId: data['relatedItemId'],
      relatedItemType: data['relatedItemType'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'relatedItemId': relatedItemId,
      'relatedItemType': relatedItemType,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    String? relatedItemId,
    String? relatedItemType,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      relatedItemId: relatedItemId ?? this.relatedItemId,
      relatedItemType: relatedItemType ?? this.relatedItemType,
    );
  }
}
