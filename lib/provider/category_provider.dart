import 'package:budgetbuddy_app/data%20models/budget_models.dart';
import 'package:budgetbuddy_app/repos/category_repo.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'base_provider.dart';

class CategoryProvider extends BaseCacheProvider {
  // Singleton pattern
  static final CategoryProvider _instance = CategoryProvider._internal();
  factory CategoryProvider() => _instance;
  CategoryProvider._internal();

  final CategoryRepo _categoryRepo = CategoryRepo();

  // State variables
  List<BudgetCategory> _categories = [];
  bool _isLoading = false;
  String? _error;
  String? _currentCategoryId;

  // Getters
  List<BudgetCategory> get categories => _categories;
  String? get currentCategoryId => _currentCategoryId;
  @override
  bool get isLoading => _isLoading;
  @override
  String? get error => _error;
  // Category selection
  void selectCategory(String categoryId) {
    _currentCategoryId = categoryId;
    notifyListeners();
  }

  // Load categories
  Future<void> loadCategories({
    bool forceRefresh = false,
    String? categoryType,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      _categories = await _categoryRepo.getCategories(
        forceRefresh: forceRefresh,
        categoryType: categoryType,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // Add category
  Future<void> addCategory(Map<String, dynamic> categoryData) async {
    _setLoading(true);
    _error = null;

    try {
      await _categoryRepo.addCategory(categoryData);
      await loadCategories(forceRefresh: true);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _currentCategoryId = null;
    _categories.clear();
    _categoryRepo.clearCache();
    super.dispose();
  }
  
  @override
  Future<void> initialize() async {
    if (_categories.isEmpty && !_isLoading) {
      await loadCategories();
    }
  }

  // Add lazy initialization helper
  static Future<void> ensureInitialized(BuildContext context) async {
    final provider = Provider.of<CategoryProvider>(context, listen: false);
    if (provider.categories.isEmpty && !provider._isLoading) {
      await provider.initialize();
    }
  }
}
