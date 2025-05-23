import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String categoryId;
  final double amount;
  final String type;
  final DateTime createdAt;
  final String? note;

  TransactionModel(
      {required this.id,
      required this.amount,
      required this.categoryId,
      required this.type,
      required this.createdAt,
      this.note});

  //deserializes data from firestore
  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return TransactionModel(
        id: data['id'],
        amount: (data['amount'] ?? 0).toDouble(),
        categoryId: data['categoryId'] ?? "",
        type: data['type'] ?? "",
        createdAt: data['createdAt'] is Timestamp
            ? (data['cretaedAt'] as Timestamp).toDate()
            : DateTime.now(),
        note: data['note']);
  }
  //serializes data to firestore compatible
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'categoryId': categoryId,
      'amount': amount,
      'Type': type,
      'note': note,
    };
  }
}
