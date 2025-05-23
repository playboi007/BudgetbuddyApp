import 'package:budgetbuddy_app/provider/category_provider.dart';
import 'package:budgetbuddy_app/repos/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:budgetbuddy_app/repos/reports_service.dart';

import 'package:budgetbuddy_app/data models/transaction_model.dart';
import 'package:flutter/foundation.dart';

class TransactionsService {
  final _firebaseService = FirebaseService();
  final _reportsService = ReportsService();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final CategoryProvider categoryProvider = CategoryProvider();
  //getters
  final currentCategoryId = CategoryProvider().currentCategoryId;
  Future<QuerySnapshot> get catCollections =>
      _firebaseService.getUserCategoriesRaw();

  //setters

  // Add a transaction (deposit or withdrawal) using TransactionModel
  Future<void> addTransaction(TransactionModel txn) async {
    final categoryRef = _firebaseService.getCategoryDocRef(txn.categoryId);

    // Build transaction data from the model and override the date & add userId
    final transactionData = txn.toFirestore()
      ..addAll({
        'date': FieldValue.serverTimestamp(),
        'userId': _firebaseService.currentUserId,
      });

    //firebase transaction that ensures acid properties are kept
    await firestore.runTransaction((transaction) async {
      final categorySnapshot = await transaction.get(categoryRef);
      if (!categorySnapshot.exists) throw Exception('Category does not exist');

      // Update category balance based on transaction type
      final currentAmount =
          ((categorySnapshot.data() as Map<String, dynamic>)['amount'] ?? 0.0)
              as double;
      double newAmount;
      if (txn.type == 'deposit') {
        newAmount = currentAmount + txn.amount;
      } else if (txn.type == 'withdrawal') {
        if (txn.amount > currentAmount) throw Exception('Insufficient funds');
        newAmount = currentAmount - txn.amount;
      } else {
        throw Exception('Invalid transaction type');
      }
      transaction.update(categoryRef, {'amount': newAmount});

      // Add the new transaction record in the subcollection
      final txnRef = _firebaseService
          .getTransactionsCollection(txn.categoryId)
          .doc()
          .collection('transactions')
          .doc();
      transaction.set(txnRef, transactionData);
    });

    // Update analytics: monthly summary, weekly report and ensure collections are initialized
    final now = DateTime.now();
    await _reportsService.updateMonthlySummary(now, txn.amount, txn.type);
    await _reportsService.updateWeeklyReport(now, txn.amount, txn.type);
    await _reportsService.initializeCollections();
  }

  Future<List<TransactionModel>> fetchRecentTransactions() async {
    try {
      final List<TransactionModel> allTransactions = [];
      //this list is for parallel execution
      final List<Future<void>> fetchFutures = [];
      //ill iterate through categories and get every transaction doc
      final categoryCollections = await catCollections;
      for (var catCollect in categoryCollections.docs) {
        fetchFutures.add(_firebaseService
            .getCategoryTransactions(catCollect.id)
            .then((snapshot) {
          final categoryTransacts = snapshot.docs
              .map((doc) => TransactionModel.fromFirestore(doc))
              .toList();
          allTransactions.addAll(categoryTransacts);
        }).catchError((e) {
          if (kDebugMode) {
            print('error getting transactions ${catCollect.id} : $e');
          }
        }));
      }
      await Future.wait(fetchFutures);
      allTransactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return allTransactions.take(10).toList();
    } catch (e) {
      if (kDebugMode) {
        print('error fetching categories');
      }
      rethrow;
    }
  }
}
