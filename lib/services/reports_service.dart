//this contains report query logic
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<double> getTotalSavings() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final query = _firestore
        .collectionGroup('transactions')
        .where('userId', isEqualTo: userId)
        .where('type', whereIn: ['deposit', 'withdrawal']);

    final snapshot = await query.get();

    return snapshot.docs.fold<double>(0.0, (double summ, doc) {
      final amount = doc['amount'] as double;
      return doc['type'] == 'deposit' ? summ + amount : summ - amount;
    });
  }

  Future<Map<String, double>> getCategoryBreakdown() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final Map<String, double> breakdown = {};

    // Get all categories
    final categories = await _firestore
        .collection('users')
        .doc(userId)
        .collection('categories')
        .get();

    for (final category in categories.docs) {
      final transactions = await category.reference
          .collection('transactions')
          .where('type', whereIn: ['deposit', 'allocation']).get();

      final total = transactions.docs
          .fold(0.0, (summ, doc) => summ + (doc['amount'] as double));

      breakdown[category['name']] = total;
    }

    return breakdown;
  }
}
