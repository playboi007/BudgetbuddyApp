import 'package:budgetbuddy_app/Mobile%20UI/category_report_page.dart';
import 'package:budgetbuddy_app/states/analytics_provider.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final analyticsProvider = Provider.of<AnalyticsProvider>(context);
    final categoryData = analyticsProvider.categoryBreakdown;

    if (analyticsProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (categoryData.isEmpty) {
      return const Center(child: Text('No category data available'));
    }

    // Generate pie chart sections
    List<PieChartSectionData> sections = [];
    final List<Color> colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.amber,
      Colors.pink,
      Colors.indigo,
      Colors.brown,
    ];

    double totalAmount =
        categoryData.fold(0, (sum, item) => sum + (item['amount'] as double));

    for (int i = 0; i < categoryData.length; i++) {
      final category = categoryData[i];
      final double percentage = totalAmount > 0
          ? (category['amount'] as double) / totalAmount * 100
          : 0;

      sections.add(
        PieChartSectionData(
          color: colors[i % colors.length],
          value: category['amount'],
          title: '${percentage.toStringAsFixed(1)}%',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return Column(
      children: [
        const Text(
          'Category Breakdown',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Legend
        Wrap(
          spacing: 16.0,
          runSpacing: 8.0,
          children: List.generate(
            categoryData.length,
            (index) {
              final category = categoryData[index];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategoryReportPage(
                        categoryId: category['categoryId'],
                        categoryName: category['name'],
                      ),
                    ),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      color: colors[index % colors.length],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      category['name'],
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      analyticsProvider.formatCurrency(category['amount']),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
