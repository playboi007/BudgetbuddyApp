//this file is responsible for state management of reports
import 'package:budgetbuddy_app/repos/reports_service.dart';
import 'package:intl/intl.dart';
import '../provider/base_provider.dart';

class AnalyticsProvider extends BaseCacheProvider {
  final ReportsService _reportsService = ReportsService();

  // State variables
  double _totalSavings = 0.0;
  List<Map<String, dynamic>> _categoryBreakdown = [];
  Map<String, Map<String, double>> _monthlySummary = {};
  List<Map<String, dynamic>> _savingsTrends = [];
  @override
  bool isLoading = false;
  @override
  String error = '';


  // Date range for reports
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _endDate = DateTime.now();

  // Getters
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
      error = '';
    } catch (e) {
      error = 'Failed to load analytics: ${e.toString()}';
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
    final cached = getCached<double>('analytics', 'totalSavings');
    if (cached != null) {
      _totalSavings = cached;
      return;
    }

    _setLoading(true);
    try {
      _totalSavings = await _reportsService.getTotalSavings();
      cache('analytics', 'totalSavings', _totalSavings,
          ttl: const Duration(minutes: 15));
      error = '';
    } catch (e) {
      error = 'Failed to load total savings: ${e.toString()}';
    } finally {
      _setLoading(false);
    }
  }

  // Fetch category breakdown
  Future<void> fetchCategoryBreakdown() async {
    final cached =
        getCached<List<Map<String, dynamic>>>('analytics', 'categoryBreakdown');
    if (cached != null) {
      _categoryBreakdown = cached;
      return;
    }

    _setLoading(true);
    try {
      _categoryBreakdown = await _reportsService.getCategoryBreakdown();
      cache('analytics', 'categoryBreakdown', _categoryBreakdown,
          ttl: const Duration(minutes: 30));
      error = '';
    } catch (e) {
      error = 'Failed to load category breakdown: ${e.toString()}';
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
      error = '';
    } catch (e) {
      error = 'Failed to load monthly summary: ${e.toString()}';
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
      error = '';
    } catch (e) {
      error = 'Failed to load savings trends: ${e.toString()}';
    } finally {
      _setLoading(false);
    }
  }

  // Helper to set loading state
  void _setLoading(bool loading) {
    isLoading = loading;
    notifyListeners();
  }

  // Format currency
  String formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '\$').format(amount);
  }
}
