import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:budgetbuddy_app/data models/budget_models.dart';

class BalanceAndCategories extends StatelessWidget {
  final int amount;
  final int count;

  const BalanceAndCategories(
      {super.key, required this.amount, required this.count});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue[600],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Balance Section
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 0, 0),
                        child: const Text(
                          'BALANCE',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ksh $amount',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Categories Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 20, 0),
                      child: const Text(
                        'CATEGORIES',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(30, 0, 0, 0),
                      child: Text(
                        count.toString(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Button action
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue[600],
              ),
              child: const Text('allocate funds'),
            ),
          ],
        ),
      ),
    );
  }
}

//userInfo widget
class UserAppbar extends StatelessWidget {
  final String name;

  const UserAppbar({
    super.key,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Welcome, $name',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          //an icon was here
        ],
      ),
    );
  }
}

//transaction listview widget
class TransactionView extends StatelessWidget {
  const TransactionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transactions',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[400]),
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          //here utachange item count to actual transaction data from firestore
          itemCount: 5,
          itemBuilder: (context, index) {
            //ill replace this with atual transaction data from firestore
            return TransactionItem(
              title: 'Naivas Supermarket cbd',
              amount: 'ksh 530',
              date: '12/02/2025',
              icon: Icons.shopping_cart,
            );
          },
        )
      ],
    );
  }
}

// Transaction Item Widget
class TransactionItem extends StatelessWidget {
  final String title;
  final String amount;
  final String date;
  final IconData icon;

  const TransactionItem(
      {super.key,
      required this.title,
      required this.amount,
      required this.date,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text('$amount - $date'),
        trailing: Icon(Icons.arrow_forward),
      ),
    );
  }
}

//widget that buikds the category card
class BuildCategoryCard extends StatelessWidget {
  final BudgetCategory category;

  const BuildCategoryCard({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final isSavings = category.categoryType == 'savings';
    final progress = isSavings ? (category.amount / category.goalAmount!) : 0.0;

    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.5),
            spreadRadius: 1,
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              if (isSavings)
                Icon(
                  category.isLocked ? Icons.lock : Icons.lock_open,
                  size: 18,
                  color: category.isLocked ? Colors.red : Colors.green,
                ),
            ],
          ),
          const Spacer(),
          if (isSavings)
            CircularPercentIndicator(
              radius: 40,
              lineWidth: 6,
              percent: progress.clamp(0.0, 1.0).toDouble(),
              center: Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 14),
              ),
              progressColor: _getProgressColor(category),
              circularStrokeCap: CircularStrokeCap.round,
            ),
          if (!isSavings)
            Text(
              'Ksh ${category.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          const SizedBox(height: 8),
          if (isSavings) ...[
            Text(
              'Saved: Ksh ${category.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Goal: Ksh ${category.goalAmount!.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Color _getProgressColor(BudgetCategory category) {
    if (category.isLocked) return Colors.grey;
    final progress = category.amount / category.goalAmount!;
    return progress < 0.5
        ? Colors.orange
        : progress < 0.8
            ? Colors.blue
            : Colors.green;
  }
}
