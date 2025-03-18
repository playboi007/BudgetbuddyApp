import 'dart:math' as Math;

import 'package:budgetbuddy_app/states/analytics_provider.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class MonthlySummaryBarChart extends StatelessWidget {
  const MonthlySummaryBarChart({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final analyticsProvider = Provider.of<AnalyticsProvider>(context);
    final monthlySummary = analyticsProvider.monthlySummary;

    if (analyticsProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (monthlySummary.isEmpty) {
      return const Center(child: Text('No monthly data available'));
    }

    // Sort months chronologically
    final List<String> sortedMonths = monthlySummary.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    // Prepare bar groups
    final List<BarChartGroupData> barGroups = [];

    for (int i = 0; i < sortedMonths.length; i++) {
      final monthKey = sortedMonths[i];
      final monthData = monthlySummary[monthKey]!;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: monthData['deposits'] ?? 0,
              color: Colors.green,
              width: 16,
              borderRadius: BorderRadius.circular(2),
            ),
            BarChartRodData(
              toY: monthData['withdrawals'] ?? 0,
              color: Colors.red,
              width: 16,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    }

    // Format month labels
    List<String> formattedMonths = [];
    for (String monthKey in sortedMonths) {
      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      formattedMonths.add(DateFormat('MMM').format(DateTime(year, month)));
    }

    return Column(
      children: [
        const Text(
          'Monthly Summary',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: barGroups.fold(
                      0.0,
                      (max, group) => Math.max(
                          max,
                          group.barRods
                              .fold(0.0, (sum, rod) => sum + rod.toY))) *
                  1.2,
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value < 0 || value >= formattedMonths.length) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        //axisSide: meta.axisSide,
                        child: Text(
                          formattedMonths[value.toInt()],
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return SideTitleWidget(
                        meta: meta,
                        //axisSide: meta.axisSide,
                        child: Text(
                          '\$${value.toInt()}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                    reservedSize: 40,
                  ),
                ),
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(show: true),
              barGroups: barGroups,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  color: Colors.green,
                ),
                const SizedBox(width: 4),
                const Text('Deposits'),
              ],
            ),
            const SizedBox(width: 24),
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  color: Colors.red,
                ),
                const SizedBox(width: 4),
                const Text('Withdrawals'),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
