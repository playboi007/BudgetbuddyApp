import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:budgetbuddy_app/utils/constants/enums.dart';

class BudgetCategory {
  final String id;
  final String name;
  final double amount;
  final String categoryType;
  final double? goalAmount;
  final bool isLocked;
  final DateTime createdAt;
  final DateTime? reminderDate;
  final ReminderFrequency reminderFrequency;

  BudgetCategory({
    required this.id,
    required this.name,
    required this.amount,
    required this.categoryType,
    this.goalAmount,
    this.isLocked = false,
    required this.createdAt,
    this.reminderDate,
    this.reminderFrequency = ReminderFrequency.none,
  });

  factory BudgetCategory.fromFirestore(Map<String, dynamic> data) {
    return BudgetCategory(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      categoryType: data['type'] ?? 'Free',
      goalAmount: data['goalAmount'] != null
          ? (data['goalAmount'] as num).toDouble()
          : null,
      isLocked: (data['islocked'] as bool?) ?? false,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      reminderDate: data['reminderDate'] is Timestamp
          ? (data['reminderDate'] as Timestamp).toDate()
          : null,
      reminderFrequency: data['reminderFrequency'] != null
          ? ReminderFrequency.values.firstWhere(
              (e) =>
                  e.toString() ==
                  'ReminderFrequency.${data['reminderFrequency']}',
              orElse: () => ReminderFrequency.none)
          : ReminderFrequency.none,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'amount': amount,
      'categoryType': categoryType,
      'goalAmount': goalAmount,
      'isLocked': isLocked,
      'createdAt': createdAt.toIso8601String(),
      'reminderDate': reminderDate?.toIso8601String(),
      'reminderFrequency': reminderFrequency.toString().split('.').last,
    };
  }

  String get formattedAmount => 'Ksh ${amount.toStringAsFixed(0)}';
}
