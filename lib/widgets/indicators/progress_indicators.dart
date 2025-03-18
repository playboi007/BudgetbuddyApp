import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

class SavingsProgress extends StatelessWidget {
  final double currentAmount;
  final double goalAmount;
  final String categoryName;

  const SavingsProgress({
    super.key,
    required this.currentAmount,
    required this.goalAmount,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    final progress = currentAmount / goalAmount;

    return CircularPercentIndicator(
      radius: 50,
      lineWidth: 12,
      animation: true,
      percent: progress.clamp(0.0, 1.0),
      center: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${(progress * 100).toStringAsFixed(1)}%'),
          Text(categoryName, style: const TextStyle(fontSize: 10)),
        ],
      ),
      progressColor: _getProgressColor(progress),
      circularStrokeCap: CircularStrokeCap.round,
    );
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.3) return Colors.red;
    if (progress < 0.7) return Colors.orange;
    return Colors.green;
  }
}
