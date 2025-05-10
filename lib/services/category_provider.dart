import 'package:budgetbuddy_app/data%20models/budget_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:budgetbuddy_app/services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'base_provider.dart';

class CategoryProvider extends BaseProvider {
  static final CategoryProvider _instance = CategoryProvider._internal();
  factory CategoryProvider() => _instance;
  CategoryProvider._internal();

  final FirebaseService _firebaseService = FirebaseService();
  List<BudgetCategory> _categoryModels = [];
  bool _isLoading = false;
  String? _error;

  // Add cache related fields
  DateTime? _lastFetchTime;
  static const Duration _cacheExpiration = Duration(minutes: 15);
  final Map<String, DateTime> _lastTypeRefresh = {};
  bool _isCacheValid = false;

  // Essential getters
  List<BudgetCategory> get categoryModels {
    _checkCacheValidity();
    return _categoryModels;
  }

  @override
  bool get isLoading => _isLoading;
  @override
  String? get error => _error;

  void _setLoading(bool value) {
    _isLoading = value;
  }

  void _checkCacheValidity() {
    if (_lastFetchTime == null) {
      _isCacheValid = false;
      return;
    }
    _isCacheValid =
        DateTime.now().difference(_lastFetchTime!) < _cacheExpiration;
  }

  Future<List<BudgetCategory>> getCategoriesWithCache({
    bool forceRefresh = false,
    String? categoryType,
  }) async {
    if (!forceRefresh && _isCacheValid) {
      if (categoryType != null) {
        return _categoryModels
            .where((cat) => cat.categoryType == categoryType)
            .toList();
      }
      return _categoryModels;
    }

    await loadCategories();
    return categoryType != null
        ? _categoryModels
            .where((cat) => cat.categoryType == categoryType)
            .toList()
        : _categoryModels;
  }

  /// Loads categories from Firebase and converts to models
  Future<void> loadCategories() async {
    if (_isLoading) return;
    _setLoading(true);

    try {
      // Try to get from cache first
      final cached = getCached<List<BudgetCategory>>('categories', 'all');
      if (cached != null) {
        _categoryModels = cached;
        _setLoading(false);
        return;
      }

      final snapshot = await _firebaseService.getUserCategories().get();

      _categoryModels = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return BudgetCategory(
          id: doc.id,
          name: data['name'] ?? '',
          amount: (data['amount'] ?? 0).toDouble(),
          categoryType: data['categoryType'] ?? '',
          goalAmount: (data['goalAmount'] ?? 0).toDouble(),
          isLocked: data['isLocked'] ?? false,
          createdAt: (data['createdAt'] as Timestamp).toDate(),
        );
      }).toList();

      // Cache the categories with 5 minute TTL
      cache('categories', 'all', _categoryModels, 
        ttl: const Duration(minutes: 5)
      );
      
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error loading categories: $e');
      }
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Adds a new category
  Future<void> addCategory(Map<String, dynamic> categoryData) async {
    try {
      final doc = await _firebaseService.addCategory(categoryData);
      final newCategory = BudgetCategory(
        id: doc.id,
        name: categoryData['name'],
        amount: categoryData['amount'],
        categoryType: categoryData['categoryType'],
        goalAmount: categoryData['goalAmount'],
        isLocked: categoryData['isLocked'],
        createdAt: DateTime.now(),
      );

      _categoryModels.insert(0, newCategory);
      _lastTypeRefresh[categoryData['categoryType']] = DateTime.now();
      clearCache('categories'); // Invalidate cache after adding
      await loadCategories(); // Reload categories
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Updates a category
  Future<void> updateCategory(
      String id, Map<String, dynamic> updatedData) async {
    try {
      await _firebaseService.updateCategory(id, updatedData);

      final index = _categoryModels.indexWhere((cat) => cat.id == id);
      if (index != -1) {
        _categoryModels[index] = _categoryModels[index].copyWith(updatedData);
      }
      clearCache('categories'); // Invalidate cache after updating
      await loadCategories(); // Reload categories
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  /// Deletes a category
  Future<void> deleteCategory(String id) async {
    try {
      await _firebaseService.deleteCategory(id);
      _categoryModels.removeWhere((cat) => cat.id == id);
      clearCache('categories'); // Invalidate cache after deleting
      await loadCategories(); // Reload categories
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  //adds a featured goal as a savings category
  Future<void> addFeaturedGoalAsCategory(Map<String, dynamic> goalData) async {
    try {
      await _firebaseService.addCategory(
        {
          'name': goalData['title'],
          'amount': 0,
          'categoryType': 'savings',
          'goalAmount': goalData['recommendedAmount'],
          'isLocked': false,
        },
      );
      await loadCategories();
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error adding featured goal as category: $e');
      }
    }
  }

  @override
  Future<void> initialize() async {
    if (_categoryModels.isEmpty && !_isLoading) {
      await loadCategories();
    }
  }

  // Add lazy initialization helper
  static Future<void> ensureInitialized(BuildContext context) async {
    final provider = Provider.of<CategoryProvider>(context, listen: false);
    if (provider._categoryModels.isEmpty && !provider._isLoading) {
      await provider.initialize();
    }
  }

  // Add memory cache
  static final Map<String, List<BudgetCategory>> _typeCache = {};

  Future<List<BudgetCategory>> getCategoriesByType(String type) async {
    if (_typeCache.containsKey(type) && _isCacheValid) {
      return _typeCache[type]!;
    }

    final categories = await getCategoriesWithCache();
    _typeCache[type] = categories.where((c) => c.categoryType == type).toList();
    return _typeCache[type]!;
  }

  Future<BudgetCategory?> getCategoryById(String categoryId) async {
    try {
      // Try cache first
      final cached = getCached<BudgetCategory>('categories', 'id_$categoryId');
      if (cached != null) return cached;

      final doc = await (_firebaseService.getUserCategories() as CollectionReference).doc(categoryId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      final category = BudgetCategory(
          id: doc.id,
          name: data['name'] ?? '',
          amount: (data['amount'] ?? 0).toDouble(),
          categoryType: data['categoryType'] ?? '',
          goalAmount: (data['goalAmount'] ?? 0).toDouble(),
          isLocked: data['isLocked'] ?? false,
          createdAt: (data['createdAt'] as Timestamp).toDate(),
      );
      
      /// Cache individual category with 5 minute TTL
      cache('categories', 'id_$categoryId', category, 
        ttl: const Duration(minutes: 5)
      );
      
      return category;
    } catch (e) {
      _error = e.toString();
      return null;
    }
  }
}
