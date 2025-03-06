import 'package:flutter/foundation.dart';
import 'package:budgetbuddy_app/services/firebase_service.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _categories = [];

  List<Map<String, dynamic>> get categories => _categories;

  Future<void> loadCategories() async {
    try {
      final snapshot = await _firebaseService.getUserCategories().first;
      _categories = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading categories: $e');
      }
      rethrow;
    }
  }

  Future<void> addCategory(Map<String, dynamic> categoryData) async {
    try {
      await _firebaseService.addCategory(categoryData);
      await loadCategories(); // Refresh the list after adding
    } catch (e) {
      if (kDebugMode) {
        print('Error adding category: $e');
      }
      rethrow;
    }
  }

  Future<void> addFeaturedGoal(Map<String, dynamic> goalData) async {
    try {
      await _firebaseService.addCategory({
        'name': goalData['title'],
        'amount': 0,
        'categoryType': 'savings',
        'goalAmount': goalData['recommendedAmount'],
        'isLocked': false,
      });
      await loadCategories(); // Refresh list
    } catch (e) {
      if (kDebugMode) print('Error adding goal: $e');
    }
  }
}
