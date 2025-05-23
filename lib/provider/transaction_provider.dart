import 'package:budgetbuddy_app/data%20models/transaction_model.dart';
import 'package:budgetbuddy_app/repos/transaction_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'base_provider.dart';

class TransactionProvider extends BaseCacheProvider {
  final _transactionService = TransactionsService();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // State variables
  bool _isLoading = false;
  String _error = '';
  List<TransactionModel> recentTransactions = [];

  // Add currentTransactionId tracking
  String? _currentTransactionId;
  String? get currentTransactionId => _currentTransactionId;

  void selectTransaction(String transactionId) {
    _currentTransactionId = transactionId;
    notifyListeners();
  }

  void clearCurrentTransaction() {
    _currentTransactionId = null;
    notifyListeners();
  }

  // Getters
  @override
  bool get isLoading => _isLoading;
  @override
  String get error => _error;

  // Adds a transaction
  Future<void> addTransaction(Map<String, dynamic> transactionData) async {
    _setLoading(true);
    _error = '';

    try {
      // Convert map to TransactionModel
      final txn = TransactionModel(
        id: '', // Will be set by Firestore
        amount: (transactionData["amount"]).toDouble(),
        categoryId: transactionData['categoryId'],
        type: transactionData['type'],
        createdAt: DateTime.now(),
        note: transactionData['note'],
      );

      await _transactionService.addTransaction(txn);

      // Refresh recent transactions
      await fetchRecentTransactions();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to add transaction: ${e.toString()}';
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // Fetch recent transactions
  Future<List<TransactionModel>> fetchRecentTransactions() async {
    _setLoading(true);
    _error = '';

    try {
       List<TransactionModel> recent = await(_transactionService.fetchRecentTransactions());
          
      recentTransactions.add(recent as TransactionModel);
      return recent;
    } catch (e) {
      _error = 'Failed to fetch recent transactions: ${e.toString()}';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Helper to set loading state
  bool _mounted = true;

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  void _setLoading(bool loading) {
    if (!_mounted) return;
    _isLoading = loading;
    Future.microtask(() => notifyListeners());
  }

  @override
  Future<void> initialize() async {
    await fetchRecentTransactions();
  }
}
