import 'package:budgetbuddy_app/utils/constants/text_strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../states/analytics_provider.dart';
import '../services/reports_service.dart';
import '../widgets/charts/line_chart.dart';

class CategoryReportPage extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const CategoryReportPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryReportPage> createState() => _CategoryReportPageState();
}

class _CategoryReportPageState extends State<CategoryReportPage> {
  final ReportsService _reportsService = ReportsService();
  bool _isLoading = false;
  Map<String, dynamic> _growthRate = {};

  @override
  void initState() {
    super.initState();
    _loadCategoryData();
  }

  Future<void> _loadCategoryData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load category growth rate data
      _growthRate =
          await _reportsService.getCategoryGrowthRate(widget.categoryId);

      if (!mounted) return;
      // Refresh the trend data
      await Provider.of<AnalyticsProvider>(context, listen: false)
          .fetchSavingsTrends(categoryId: widget.categoryId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading category data: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final analyticsProvider = Provider.of<AnalyticsProvider>(context);
    final categoryBreakdown = analyticsProvider.categoryBreakdown;

    // Find this category's data in the breakdown
    final categoryData = categoryBreakdown.firstWhere(
      (category) => category['categoryId'] == widget.categoryId,
      orElse: () => {'amount': 0.0, 'goalAmount': 0.0, 'progress': 0.0},
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.categoryName} Report'),
      ),
      body: _isLoading || analyticsProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCategoryData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Current balance card
                    _buildBalanceCard(context, categoryData),
                    const SizedBox(height: 16),

                    // Goal progress card (if goal exists)
                    if (categoryData['goalAmount'] > 0)
                      _buildGoalProgressCard(context, categoryData),
                    if (categoryData['goalAmount'] > 0)
                      const SizedBox(height: 16),

                    // Growth metrics card
                    _buildGrowthMetricsCard(context),
                    const SizedBox(height: 16),

                    // Trend chart
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SavingsTrendLineChart(
                            categoryId: widget.categoryId),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Monthly changes card (if available)
                    if (_growthRate.containsKey('monthlyChanges') &&
                        (_growthRate['monthlyChanges'] as Map).isNotEmpty)
                      _buildMonthlyChangesCard(context),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBalanceCard(
      BuildContext context, Map<String, dynamic> categoryData) {
    final analyticsProvider = Provider.of<AnalyticsProvider>(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Current Balance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              analyticsProvider.formatCurrency(categoryData['amount']),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
            ),
            Text(
              'of ${analyticsProvider.formatCurrency(categoryData['goalAmount'])}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalProgressCard(
      BuildContext context, Map<String, dynamic> categoryData) {
    final progress = categoryData['progress'] ?? 0.0;
    final progressCapped = progress > 100 ? 100.0 : progress;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TextStrings.gp,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progressCapped / 100,
              minHeight: 10,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 100 ? Colors.green : Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${progress.toStringAsFixed(1)}%'),
                if (progress < 100)
                  Text(
                    '${(100 - progress).toStringAsFixed(1)}% to go',
                    style: TextStyle(color: Colors.grey[600]),
                  )
                else
                  const Text(
                    TextStrings.gr,
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthMetricsCard(BuildContext context) {
    final isGrowing = _growthRate['isGrowing'] ?? false;
    final growthRate = _growthRate['growthRate'] ?? 0.0;
    final monthlyAverage = _growthRate['monthlyAverage'] ?? 0.0;

    final analyticsProvider = Provider.of<AnalyticsProvider>(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Growth Metrics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Growth Rate',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isGrowing ? Icons.trending_up : Icons.trending_down,
                            color: isGrowing ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${growthRate.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isGrowing ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Colors.grey[300],
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Monthly Average',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        analyticsProvider.formatCurrency(monthlyAverage),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyChangesCard(BuildContext context) {
    final analyticsProvider = Provider.of<AnalyticsProvider>(context);
    final monthlyChanges =
        _growthRate['monthlyChanges'] as Map<String, dynamic>;

    // Sort month keys
    List<String> sortedMonths = monthlyChanges.keys.toList()..sort();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Changes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...sortedMonths.map((monthKey) {
              final change = monthlyChanges[monthKey];
              final isPositive = change >= 0;

              // Parse the month key to get a readable label
              final parts = monthKey.split('-');
              final year = int.parse(parts[0]);
              final month = int.parse(parts[1]);
              final monthName =
                  DateFormat('MMMM yyyy').format(DateTime(year, month));

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(monthName),
                    Row(
                      children: [
                        Icon(
                          isPositive
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color: isPositive ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          analyticsProvider.formatCurrency(change.abs()),
                          style: TextStyle(
                            color: isPositive ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
