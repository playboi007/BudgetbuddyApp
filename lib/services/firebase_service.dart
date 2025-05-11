import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:budgetbuddy_app/services/reports_service.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ReportsService _reportsService = ReportsService();

  // Gets current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // ========== USERS COLLECTION ==========
  Future<void> createUserDocument(
      {required String name, required String email}) async {
    if (currentUserId == null) throw Exception('User not authenticated');

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
    if (currentUserId == null) throw Exception('User not logged in');
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

  Query getUserCategories() {
    if (currentUserId == null) {
      throw Exception('User not logged in');
    }
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('categories');
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
    if (currentUserId == null) throw Exception('User not logged in');

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
    if (currentUserId == null) throw Exception('User not logged in');

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
    if (currentUserId == null) throw Exception('User not logged in');
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('courseProgress');
  }

  /// Update course progress
  Future<void> updateCourseProgress(String courseId, Map<String, dynamic> data) async {
    if (currentUserId == null) throw Exception('User not logged in');
    
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
}
