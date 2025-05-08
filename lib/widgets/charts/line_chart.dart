import 'package:budgetbuddy_app/states/analytics_provider.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

class SavingsTrendLineChart extends StatelessWidget {
  final String? categoryId;

  const SavingsTrendLineChart({
    super.key,
    this.categoryId,
  });

  @override
  Widget build(BuildContext context) {
    final analyticsProvider = Provider.of<AnalyticsProvider>(context);
    final trendData = analyticsProvider.savingsTrends;

    if (analyticsProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (trendData.isEmpty) {
      return const Center(child: Text('No trend data available'));
    }

    // Prepare line chart spots
    final List<FlSpot> spots = [];

    for (int i = 0; i < trendData.length; i++) {
      spots.add(FlSpot(i.toDouble(), trendData[i]['balance']));
    }

    // Find max value for y-axis scale
    double maxY = trendData.isEmpty
        ? 0
        : trendData
            .map((e) => e['balance'] as double)
            .reduce((a, b) => a > b ? a : b);
    maxY = maxY * 1.2; // Add 20% padding to the top

    return Column(
      children: [
        Text(
          categoryId == null
              ? 'Overall Savings Trend'
              : 'Category Savings Trend',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: 1,
                verticalInterval: 1,
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value < 0 || value >= trendData.length) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        //axisSide: meta.axisSide,
                        //axisSide: AxisSide.bottom,
                        space: 8,
                        child: Text(
                          trendData[value.toInt()]['label'],
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                    reservedSize: 30,
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
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              minX: 0,
              maxX: (trendData.length - 1).toDouble(),
              minY: 0,
              maxY: maxY,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.blue.withValues(alpha: .2),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Add trend analysis
        if (trendData.length >= 2) _buildTrendAnalysis(trendData),
      ],
    );
  }

  Widget _buildTrendAnalysis(List<Map<String, dynamic>> trendData) {
    // Calculate trend percentage change
    double firstValue = trendData.first['balance'];
    double lastValue = trendData.last['balance'];
    double change = lastValue - firstValue;
    double percentChange = firstValue != 0 ? (change / firstValue) * 100 : 0;

    Color trendColor = change >= 0 ? Colors.green : Colors.red;
    IconData trendIcon = change >= 0 ? Icons.trending_up : Icons.trending_down;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: trendColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(trendIcon, color: trendColor),
          const SizedBox(width: 8),
          Text(
            '${change >= 0 ? '+' : ''}${percentChange.toStringAsFixed(1)}% over period',
            style: TextStyle(
              color: trendColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
