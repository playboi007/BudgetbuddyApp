import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";

class TransactionsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addTransaction({
    required String categoryId,
    required String type,
    required double amount,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final categoryRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('categories')
        .doc(categoryId);

    // Firestore Transaction
    await _firestore.runTransaction((transaction) async {
      // Updates Category Balance
      final categoryDoc = await transaction.get(categoryRef);
      final newBalance =
          categoryDoc['amount'] + (type == 'deposit' ? amount : -amount);
      transaction.update(categoryRef, {'amount': newBalance});

      // Creates a transaction record
      transaction.set(categoryRef.collection('transactions').doc(), {
        'type': type,
        'amount': amount,
        'date': FieldValue.serverTimestamp(),
        'userId': userId,
        'categoryId': categoryId,
      });
    });
  }
}
