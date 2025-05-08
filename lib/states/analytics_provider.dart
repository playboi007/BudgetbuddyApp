//this file is responsible for state management of reports
import 'package:budgetbuddy_app/services/reports_service.dart';
import 'package:intl/intl.dart';
import '../services/base_provider.dart';

class AnalyticsProvider extends BaseProvider {
  final ReportsService _reportsService = ReportsService();

  // State variables
  bool _isLoading = false;
  String _error = '';
  double _totalSavings = 0.0;
  List<Map<String, dynamic>> _categoryBreakdown = [];
  Map<String, Map<String, double>> _monthlySummary = {};
  List<Map<String, dynamic>> _savingsTrends = [];

  // Date range for reports
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _endDate = DateTime.now();

  // Getters
  bool get isLoading => _isLoading;
  String get error => _error;
  double get totalSavings => _totalSavings;
  List<Map<String, dynamic>> get categoryBreakdown => _categoryBreakdown;
  Map<String, Map<String, double>> get monthlySummary => _monthlySummary;
  List<Map<String, dynamic>> get savingsTrends => _savingsTrends;
  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;

  // Initialize data
  @override
  Future<void> initialize() async {
    await loadAnalytics();
  }

  Future<void> loadAnalytics() async {
    _setLoading(true);
    try {
      // Load all analytics data in parallel
      await Future.wait([
        fetchTotalSavings(),
        fetchCategoryBreakdown(),
        fetchMonthlySummary(),
        fetchSavingsTrends(),
      ]);
      _error = '';
    } catch (e) {
      _error = 'Failed to load analytics: ${e.toString()}';
    } finally {
      _setLoading(false);
    }
  }

  // Set date range
  void setDateRange(DateTime start, DateTime end) {
    _startDate = start;
    _endDate = end;
    notifyListeners();

    // Refresh reports with new date range
    fetchMonthlySummary();
    fetchSavingsTrends();
  }

  // Fetch total savings
  Future<void> fetchTotalSavings() async {
    _setLoading(true);
    try {
      _totalSavings = await _reportsService.getTotalSavings();
      _error = '';
    } catch (e) {
      _error = 'Failed to load total savings: ${e.toString()}';
    } finally {
      _setLoading(false);
    }
  }

  // Fetch category breakdown
  Future<void> fetchCategoryBreakdown() async {
    _setLoading(true);
    try {
      _categoryBreakdown = await _reportsService.getCategoryBreakdown();
      _error = '';
    } catch (e) {
      _error = 'Failed to load category breakdown: ${e.toString()}';
    } finally {
      _setLoading(false);
    }
  }

  // Fetch monthly summary
  Future<void> fetchMonthlySummary() async {
    _setLoading(true);
    try {
      _monthlySummary =
          await _reportsService.getMonthlySummary(_startDate, _endDate);
      _error = '';
    } catch (e) {
      _error = 'Failed to load monthly summary: ${e.toString()}';
    } finally {
      _setLoading(false);
    }
  }

  // Fetch savings trends
  Future<void> fetchSavingsTrends({String? categoryId}) async {
    _setLoading(true);
    try {
      _savingsTrends = await _reportsService
          .getSavingsTrends(_startDate, _endDate, categoryId: categoryId);
      _error = '';
    } catch (e) {
      _error = 'Failed to load savings trends: ${e.toString()}';
    } finally {
      _setLoading(false);
    }
  }

  // Helper to set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Format currency
  String formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '\$').format(amount);
  }
}
