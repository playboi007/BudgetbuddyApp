import 'package:flutter/material.dart';
import 'package:budgetbuddy_app/data models/budget_models.dart';

class CategoryDetailsDialog extends StatelessWidget {
  final BudgetCategory category;
  final String heroTag;

  const CategoryDetailsDialog({
    super.key,
    required this.category,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: heroTag,
            child: Center(
              child: CircleAvatar(
                radius: 50,
                child: Text(
                  category.name.substring(0, 1),
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),
          ),
          Text('Amount: Ksh ${category.amount.toStringAsFixed(2)}'),
          if (category.categoryType == 'savings')
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Goal: Ksh ${category.goalAmount?.toStringAsFixed(2)}'),
                  Text('Status: ${category.isLocked ? 'Locked' : 'Unlocked'}'),
                ],
              ),
              //we'll add here buttons for transacting and like options for deleting, editing and more
            ),
        ],
      ),
    );
  }
}
