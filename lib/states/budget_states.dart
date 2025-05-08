import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:budgetbuddy_app/data models/budget_models.dart';

class BudgetState extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<BudgetCategory> _categories = [];
  double _totalBalance = 0;
  bool _isLoading = true;

  List<BudgetCategory> get categories => _categories;
  double get totalBalance => _totalBalance;
  bool get isLoading => _isLoading;
  int get categoryCount => _categories.length;

  BudgetState() {
    _initializeListeners();
  }

  void _initializeListeners() {
    _firestore.collection('Categories').snapshots().listen((snapshot) {
      _categories = snapshot.docs
          .map((doc) =>
              BudgetCategory.fromFirestore({'id': doc.id, ...doc.data()}))
          .toList();
      _calculateTotalBalance();
      _isLoading = false;
      notifyListeners();
    });
  }

  void _calculateTotalBalance() {
    _totalBalance =
        _categories.fold(0, (summ, category) => summ + category.amount);
  }

  Future<void> addCategory(
    String name,
    double amount,
    String categoryType, {
    double? goalAmount,
    bool? isLocked,
  }) async {
    try {
      await _firestore.collection('categories').add({
        'name': name,
        'amount': amount,
        'type': categoryType,
        'targetAmount': goalAmount,
        'lockTillTarget': isLocked ?? false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding category: $e');
      }

      rethrow;
    }
  }
}
