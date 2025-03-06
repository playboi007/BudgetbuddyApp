//this file is responsible for state management of reports
import 'package:budgetbuddy_app/services/reports_service.dart';
import 'package:flutter/foundation.dart';

class AnalyticsProvider with ChangeNotifier {
  final ReportsService _reportsService = ReportsService();
  Map<String, double>? _categoryBreakdown;

  Map<String, double>? get categoryBreakdown => _categoryBreakdown;

  Future<void> loadCategoryBreakdown() async {
    _categoryBreakdown = await _reportsService.getCategoryBreakdown();
    notifyListeners();
  }
}
