import 'package:budgetbuddy_app/services/transaction_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionProvider with ChangeNotifier {
  final TransactionsService _transactionsService = TransactionsService();

  // State variables
  bool _isLoading = false;
  String _error = '';
  List<Map<String, dynamic>> _recentTransactions = [];

  // Getters
  bool get isLoading => _isLoading;
  String get error => _error;
  List<Map<String, dynamic>> get recentTransactions => _recentTransactions;

  // Add a transaction
  Future<void> addTransaction(
      {required String categoryId,
      required String transactionType,
      required double amount,
      String? note}) async {
    _setLoading(true);
    _error = '';

    try {
      await _transactionsService.addTransaction(
        categoryId: categoryId,
        transactionType: transactionType,
        amount: amount,
        note: note,
      );

      // Refresh recent transactions
      await fetchRecentTransactions();
    } catch (e) {
      _error = 'Failed to add transaction: ${e.toString()}';
    } finally {
      _setLoading(false);
    }
  }

  // Delete a transaction
  Future<void> deleteTransaction(
      String categoryId, String transactionId) async {
    _setLoading(true);
    _error = '';

    try {
      await _transactionsService.deleteTransaction(categoryId, transactionId);

      // Remove from local state
      _recentTransactions.removeWhere((transaction) =>
          transaction['transactionId'] == transactionId &&
          transaction['categoryId'] == categoryId);

      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete transaction: ${e.toString()}';
    } finally {
      _setLoading(false);
    }
  }

  // Fetch recent transactions
  Future<void> fetchRecentTransactions({int limit = 10}) async {
    _setLoading(true);
    _error = '';

    try {
      // Get all categories
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      String? userId = _transactionsService.currentUserId;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      QuerySnapshot categoriesSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .get();

      List<Map<String, dynamic>> allTransactions = [];

      // For each category, get recent transactions
      for (var categoryDoc in categoriesSnapshot.docs) {
        String categoryId = categoryDoc.id;
        Map<String, dynamic> categoryData =
            categoryDoc.data() as Map<String, dynamic>;

        QuerySnapshot transactionsSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('categories')
            .doc(categoryId)
            .collection('transactions')
            .orderBy('date', descending: true)
            .limit(limit)
            .get();

        for (var transactionDoc in transactionsSnapshot.docs) {
          Map<String, dynamic> transactionData =
              transactionDoc.data() as Map<String, dynamic>;

          allTransactions.add({
            'transactionId': transactionDoc.id,
            'categoryId': categoryId,
            'categoryName': categoryData['name'] ?? 'Unknown',
            'amount': transactionData['amount'] ?? 0.0,
            'transactionType': transactionData['transactionType'] ?? '',
            'date': transactionData['date'],
            'note': transactionData['note'] ?? '',
          });
        }
      }

      // Sort by date (newest first)
      allTransactions.sort((a, b) {
        Timestamp aDate = a['date'];
        Timestamp bDate = b['date'];
        return bDate.compareTo(aDate);
      });

      // Take only the most recent transactions
      _recentTransactions = allTransactions.take(limit).toList();

      notifyListeners();
    } catch (e) {
      _error = 'Failed to fetch recent transactions: ${e.toString()}';
    } finally {
      _setLoading(false);
    }
  }

  // Helper to set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
