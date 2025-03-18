import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TransactionsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  
  // Collection references
  CollectionReference get _usersCollection => _firestore.collection('users');
  
  // Get categories collection for current user
  CollectionReference _getCategoriesCollection() {
    return _usersCollection.doc(currentUserId).collection('categories');
  }
  
  // Get transactions collection for a specific category
  CollectionReference _getTransactionsCollection(String categoryId) {
    return _getCategoriesCollection().doc(categoryId).collection('transactions');
  }
  
  // Add a transaction (deposit or withdrawal)
  Future<void> addTransaction({
    required String categoryId, 
    required String transactionType, 
    required double amount, 
    String? note
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    // Create transaction data
    final transactionData = {
      'transactionType': transactionType,
      'amount': amount,
      'date': FieldValue.serverTimestamp(),
      'userId': _usersCollection.doc(currentUserId),
      'categoryId': _getCategoriesCollection().doc(categoryId),
      'note': note,
    };
    
    // Use a transaction to update both the transaction record and category balance
    return _firestore.runTransaction((transaction) async {
      // Get the category document
      DocumentReference categoryRef = _getCategoriesCollection().doc(categoryId);
      DocumentSnapshot categorySnapshot = await transaction.get(categoryRef);
      
      if (!categorySnapshot.exists) {
        throw Exception('Category does not exist');
      }
      
      // Get current amount
      double currentAmount = (categorySnapshot.data() as Map<String, dynamic>)['amount'] ?? 0.0;
      
      // Calculate new amount based on transaction type
      double newAmount;
      if (transactionType == 'deposit') {
        newAmount = currentAmount + amount;
      } else if (transactionType == 'withdrawal') {
        if (amount > currentAmount) {
          throw Exception('Insufficient funds');
        }
        newAmount = currentAmount - amount;
      } else {
        throw Exception('Invalid transaction type');
      }
      
      // Update category amount
      transaction.update(categoryRef, {'amount': newAmount});
      
      // Add transaction record
      DocumentReference transactionRef = _getTransactionsCollection(categoryId).doc();
      transaction.set(transactionRef, transactionData);
    });
  }
  
  // Get all transactions for a specific category
  Stream<QuerySnapshot> getCategoryTransactions(String categoryId) {
    return _getTransactionsCollection(categoryId)
        .orderBy('date', descending: true)
        .snapshots();
  }
  
  // Get transactions for a specific category within a date range
  Stream<QuerySnapshot> getCategoryTransactionsInRange(
    String categoryId, 
    DateTime startDate, 
    DateTime endDate
  ) {
    return _getTransactionsCollection(categoryId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date', descending: true)
        .snapshots();
  }
  
  // Delete a transaction (with balance update)
  Future<void> deleteTransaction(String categoryId, String transactionId) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    return _firestore.runTransaction((transaction) async {
      // Get the transaction document
      DocumentReference transactionRef = _getTransactionsCollection(categoryId).doc(transactionId);
      DocumentSnapshot transactionSnapshot = await transaction.get(transactionRef);
      
      if (!transactionSnapshot.exists) {
        throw Exception('Transaction does not exist');
      }
      
      // Get transaction data
      Map<String, dynamic> transactionData = transactionSnapshot.data() as Map<String, dynamic>;
      String type = transactionData['transactionType'];
      double amount = transactionData['amount'];
      
      // Get the category document
      DocumentReference categoryRef = _getCategoriesCollection().doc(categoryId);
      DocumentSnapshot categorySnapshot = await transaction.get(categoryRef);
      
      if (!categorySnapshot.exists) {
        throw Exception('Category does not exist');
      }
      
      // Get current amount
      double currentAmount = (categorySnapshot.data() as Map<String, dynamic>)['amount'] ?? 0.0;
      
      // Calculate new amount based on transaction type (reverse the original transaction)
      double newAmount;
      if (type == 'deposit') {
        newAmount = currentAmount - amount;
      } else if (type == 'withdrawal') {
        newAmount = currentAmount + amount;
      } else {
        throw Exception('Invalid transaction type');
      }
      
      // Update category amount
      transaction.update(categoryRef, {'amount': newAmount});
      
      // Delete transaction record
      transaction.delete(transactionRef);
    });
  }
}