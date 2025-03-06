import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetCategory {
  final String id;
  final String name;
  final double amount;
  final String categoryType;
  final double? goalAmount;
  final bool isLocked;
  final DateTime createdAt;

  BudgetCategory({
    required this.id,
    required this.name,
    required this.amount,
    required this.categoryType,
    this.goalAmount,
    this.isLocked = false,
    required this.createdAt,
  });

  factory BudgetCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BudgetCategory(
      id: doc.id,
      name: data['name'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      categoryType: data['type'] ?? 'Free',
      goalAmount: (data['goalAmount'] ?? 0).toDouble(),
      isLocked: (data['islocked'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
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
    };
  }

  String get formattedAmount => 'Ksh ${amount.toStringAsFixed(0)}';
}
