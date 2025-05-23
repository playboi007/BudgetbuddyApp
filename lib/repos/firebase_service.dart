import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:budgetbuddy_app/repos/reports_service.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  //reports service is here because the functions that trigger some operations are being client processed
  final ReportsService _reportsService = ReportsService();

  // Gets current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // ========== USERS COLLECTION ==========
  Future<void> createUserDocument(
      {required String name, required String email}) async {
    try {
      final userDoc = _firestore.collection('users').doc(currentUserId);

      // Check if user document already exists
      final docSnapshot = await userDoc.get();
      if (!docSnapshot.exists) {
        await userDoc.set({
          'name': name,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'totalSavings': 0.0,
        });

        // Initialize analytics collections for the new user
        await _reportsService.initializeCollections();
      }
    } catch (e) {
      throw Exception('Failed to create user document: $e');
    }
  }

  // ========== CATEGORIES COLLECTION ==========
  Future<DocumentReference> addCategory(Map<String, dynamic> data) async {
    try {
      DocumentReference docRef = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('categories')
          .add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef;
    } catch (e) {
      throw Exception('Failed to add category: $e');
    }
  }

  Future<QuerySnapshot> getUserCategories() async {
    return await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('categories')
        .orderBy('date', descending: true)
        .get();
  }

  // Get categories collection for current user
  CollectionReference getCategoriesCollection() {
    return _getUserDoc().collection('categories');
  }

  // Get category document reference
  DocumentReference getCategoryDocRef(String categoryId) {
    return getCategoriesCollection().doc(categoryId);
  }

  // New method added to fetch a single category document by ID
  Future<DocumentSnapshot> getSingleCategoryRaw(String categoryId) async {
    return await FirebaseFirestore.instance
        .collection('categories')
        .doc(categoryId)
        .get();
  }

  // Get all category docs for current user
  Future<QuerySnapshot> getUserCategoriesRaw() async {
    return await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('categories')
        .get();
  }

  // Featured Goals Collection Operations
  Future<QuerySnapshot> getFeaturedGoals() async {
    try {
      return await _firestore.collection('featured_goals').get();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching featured goals: $e');
      }
      rethrow;
    }
  }

  /// Updates a category document by ID
  Future<void> updateCategory(
      String categoryId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('categories')
          .doc(categoryId)
          .update(data);
    } catch (e) {
      throw Exception('Failed to update category: $e');
    }
  }

  /// Deletes a category document by ID
  Future<void> deleteCategory(String categoryId) async {
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('categories')
          .doc(categoryId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete category: $e');
    }
  }

  // ========== COURSES COLLECTION ==========

  /// Get all courses
  CollectionReference getCourses() {
    return _firestore.collection('courses');
  }

  /// Get specific course
  DocumentReference getCourse(String courseId) {
    return _firestore.collection('courses').doc(courseId);
  }

  /// Get user's course progress
  CollectionReference getCourseProgress() {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('courseProgress');
  }

  /// Update course progress
  Future<void> updateCourseProgress(
      String courseId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('courseProgress')
          .doc(courseId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update course progress: $e');
    }
  }

  // ============ Reports collections ============

  // Get user document reference
  DocumentReference _getUserDoc() {
    return _firestore.collection('users').doc(currentUserId);
  }

  // Get weekly reports collection
  DocumentReference getWeeklyReportDocRef(String weekId) {
    return FirebaseFirestore.instance.collection('weeklyReports').doc(weekId);
  }

  // Get monthly summaries collection by month key
  DocumentReference getMonthlySummaryDocRef(String monthKey) {
    return FirebaseFirestore.instance
        .collection('monthlySummaries')
        .doc(monthKey);
  }

  // Get all transactions for a category in a date range
  Future<QuerySnapshot> fetchCategoryTransactionsRaw(
      String categoryId, DateTime start, DateTime end) async {
    return await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('categories')
        .doc(categoryId)
        .collection('transactions')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
  }

  // Get all monthly summaries for current user
  Future<QuerySnapshot> fetchMonthlySummariesRaw() async {
    if (currentUserId == null) throw Exception('User not authenticated');
    return await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('monthlySummaries')
        .get();
  }

  // Get all weekly reports for current user
  Future<QuerySnapshot> fetchWeeklyReportsRaw() async {
    if (currentUserId == null) throw Exception('User not authenticated');
    return await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('weeklyReports')
        .get();
  }

  /// ===================transaction===================

  // Get transactions collection for a specific category
  CollectionReference getTransactionsCollection(
    String categoryId,
  ) {
    return getCategoriesCollection()
        .doc(categoryId)
        .collection('transactions');
  }

  //Document snapshot of all transactions
  Future<DocumentSnapshot> readUsertransactions(String categoryId,
      [String? transactionId]) async {
    final query = getTransactionsCollection(categoryId);

    return transactionId != null
        ? await query.doc(transactionId).get()
        : await query.limit(1).get().then((snap) => snap.docs.first);
  }
  
  // Get all transactions for a specific category
  Future<QuerySnapshot> getCategoryTransactions(String categoryId) {
    return getTransactionsCollection(categoryId)
        .orderBy('date', descending: true)
        .limit(10)
        .get();
  }

  // Get transactions for a specific category within a date range
  Stream<QuerySnapshot> getCategoryTransactionsInRange(
      String categoryId, DateTime startDate, DateTime endDate) {
    return getTransactionsCollection(categoryId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date', descending: true)
        .snapshots();
  }

  //adds a transaction
  Future<DocumentReference> addTransaction(Map<String, dynamic> data) async {
    try {
      DocumentReference transactionRef = await getCategoriesCollection().add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return transactionRef;
    } catch (e) {
      throw Exception("failed to add transaction");
    }
  }

  // fetches recent transactions from all user categories
  /*Stream<QuerySnapshot> getAllRecentTransactions() {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('categories')
        .snapshots()
        .asyncExpand((categorySnapshot) {
      final Iterable<Stream<QuerySnapshot<Object?>>> futures = categorySnapshot.docs.map((categoryDoc) {
        return getTransactionsCollection(categoryDoc.id)
            .orderBy('date', descending: true)
            .limit(5)
            .snapshots();
      });
      return Stream.fromFutures(futures);
    });
  }*/

  
}
