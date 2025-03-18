import 'package:budgetbuddy_app/states/analytics_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
