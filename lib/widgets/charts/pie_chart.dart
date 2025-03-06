import 'package:flutter/material.dart';
// Ensure you have imported the package providing PieChart using, e.g., fl_chart package.
import 'package:fl_chart/fl_chart.dart';

class CategoryPieChart extends StatelessWidget {
  final Map<String, double> data;
  
  const CategoryPieChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        sections: data.entries.map((entry) {
          return PieChartSectionData(
            color: _getCategoryColor(entry.key),
            value: entry.value,
            title: entry.key,
          );
        }).toList(),
      ),
    );
  }

  // Placeholder for category color function
  Color _getCategoryColor(String category) {
    return Colors.blue; // Example default
  }
}