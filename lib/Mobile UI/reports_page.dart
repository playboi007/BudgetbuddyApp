import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../states/analytics_provider.dart';
import '../widgets/charts/pie_chart.dart';
import '../widgets/charts/bar_chart.dart';
import '../widgets/charts/line_chart.dart';
import 'package:intl/intl.dart';
import 'package:budgetbuddy_app/services/reports_service.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final ReportsService _reportsService = ReportsService();
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    // Initialize the analytics provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AnalyticsProvider>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final analyticsProvider = Provider.of<AnalyticsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _showDateRangePicker(context),
          ),
        ],
      ),
      body: analyticsProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildReportContent(context),
    );
  }

  Widget _buildReportContent(BuildContext context) {
    final analyticsProvider = Provider.of<AnalyticsProvider>(context);

    if (analyticsProvider.error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading reports: ${analyticsProvider.error}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => analyticsProvider.initialize(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Weekly reports card
    FutureBuilder<List<Map<String, dynamic>>>(
      future: _reportsService.getWeeklyReports(limit: 3),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading weekly reports: ${snapshot.error}'),
          );
        }

        final weeklyReports = snapshot.data ?? [];

        if (weeklyReports.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Weekly Reports',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to a full weekly reports page if needed
                      },
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...weeklyReports.map((report) {
                  final startDate = (report['startDate'] as Timestamp).toDate();
                  final endDate = (report['endDate'] as Timestamp).toDate();
                  final net = report['net'] as double;
                  final isPositive = net >= 0;

                  return ListTile(
                    title: Text(
                      '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d').format(endDate)}',
                    ),
                    subtitle: Text(
                      'Deposits: ${analyticsProvider.formatCurrency(report['deposits'])}\n'
                      'Withdrawals: ${analyticsProvider.formatCurrency(report['withdrawals'])}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          analyticsProvider.formatCurrency(net.abs()),
                          style: TextStyle(
                            color: isPositive ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: isPositive ? Colors.green : Colors.red,
                              size: 12,
                            ),
                            Text(
                              isPositive ? 'Saved' : 'Spent',
                              style: TextStyle(
                                color: isPositive ? Colors.green : Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );

    return RefreshIndicator(
      onRefresh: () => analyticsProvider.initialize(),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date range indicator
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Date Range',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('MMM d, yyyy')
                                .format(analyticsProvider.startDate),
                          ),
                          const Text(' — '),
                          Text(
                            DateFormat('MMM d, yyyy')
                                .format(analyticsProvider.endDate),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Total savings overview
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Total Savings',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        analyticsProvider
                            .formatCurrency(analyticsProvider.totalSavings),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Category breakdown
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: const CategoryPieChart(),
                ),
              ),
              const SizedBox(height: 16),

              // Monthly summary
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: const MonthlySummaryBarChart(),
                ),
              ),
              const SizedBox(height: 16),

              // Category selector for trends
              if (analyticsProvider.categoryBreakdown.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Select Category for Trend',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        DropdownButton<String?>(
                          isExpanded: true,
                          value: _selectedCategoryId,
                          hint: const Text('All Categories'),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategoryId = value;
                            });
                            analyticsProvider.fetchSavingsTrends(
                              categoryId: value,
                            );
                          },
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All Categories'),
                            ),
                            ...analyticsProvider.categoryBreakdown
                                .map((category) {
                              return DropdownMenuItem<String?>(
                                value: category['categoryId'],
                                child: Text(category['name']),
                              );
                            }).toList(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Savings trends
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SavingsTrendLineChart(categoryId: _selectedCategoryId),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDateRangePicker(BuildContext context) async {
    final analyticsProvider =
        Provider.of<AnalyticsProvider>(context, listen: false);

    final initialDateRange = DateTimeRange(
      start: analyticsProvider.startDate,
      end: analyticsProvider.endDate,
    );

    final pickedDateRange = await showDateRangePicker(
      context: context,
      initialDateRange: initialDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDateRange != null) {
      analyticsProvider.setDateRange(
        pickedDateRange.start,
        pickedDateRange.end,
      );
    }
  }
}
