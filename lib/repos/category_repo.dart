import 'package:budgetbuddy_app/data%20models/budget_models.dart';
import 'package:budgetbuddy_app/repos/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryRepo {
  // Singleton pattern
  static final CategoryRepo _instance = CategoryRepo._internal();
  factory CategoryRepo() => _instance;
  CategoryRepo._internal();

  final FirebaseService _firebaseService = FirebaseService();

  // Cache management
  final Map<String, List<BudgetCategory>> _typeCache = {};
  DateTime? _lastFetchTime;
  static const Duration _cacheExpiration = Duration(minutes: 15);

  // Load categories with caching
  Future<List<BudgetCategory>> getCategories({
    bool forceRefresh = false,
    String? categoryType,
  }) async {
    if (!forceRefresh && _isCacheValid && _typeCache.isNotEmpty) {
      if (categoryType != null) {
        return _typeCache[categoryType] ?? [];
      }
      return _typeCache.values.expand((e) => e).toList();
    }

    try {
      final snapshot = await _firebaseService.getUserCategories();
      final categories = _processCategories(snapshot);
      _updateCache(categories);
      return categoryType != null
          ? categories.where((c) => c.categoryType == categoryType).toList()
          : categories;
    } catch (e) {
      throw Exception('Failed to load categories: $e');
    }
  }

  // Add new category
  Future<BudgetCategory> addCategory(Map<String, dynamic> categoryData) async {
    try {
      final docRef = await _firebaseService.addCategory(categoryData);
      final doc = await docRef.get();
      final category = BudgetCategory.fromFirestore(doc as Map<String, dynamic>);
      _updateSingleCategory(category);
      return category;
    } catch (e) {
      throw Exception('Failed to add category: $e');
    }
  }

  // Private helper methods
  void _updateCache(List<BudgetCategory> categories) {
    _typeCache.clear();
    for (var category in categories) {
      _typeCache.putIfAbsent(category.categoryType, () => []).add(category);
    }
    _lastFetchTime = DateTime.now();
  }

  void _updateSingleCategory(BudgetCategory category) {
    _typeCache.putIfAbsent(category.categoryType, () => []).add(category);
  }

  bool get _isCacheValid {
    if (_lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheExpiration;
  }

  List<BudgetCategory> _processCategories(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      return BudgetCategory.fromFirestore(doc as Map<String, dynamic>);
    }).toList();
  }

  void clearCache() {
    _typeCache.clear();
    _lastFetchTime = null;
  }
}
