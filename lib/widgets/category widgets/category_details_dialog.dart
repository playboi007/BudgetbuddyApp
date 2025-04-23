import 'package:budgetbuddy_app/utils/theme/text_theme.dart';
import 'package:flutter/material.dart';
import 'package:budgetbuddy_app/data models/budget_models.dart';

class CategoryDetailsDialog extends StatefulWidget {
  final BudgetCategory category;
  final String heroTag;

  const CategoryDetailsDialog({
    super.key,
    required this.category,
    required this.heroTag,
  });

  @override
  State<CategoryDetailsDialog> createState() => _CategoryDetailsDialogState();
}

class _CategoryDetailsDialogState extends State<CategoryDetailsDialog> {
  late double amount;
  late double? goalAmount;
  late bool isSavingsCategory;

  @override
  void initState() {
    super.initState();
    amount = widget.category.amount;
    isSavingsCategory = widget.category.categoryType.toLowerCase() == 'savings';
    goalAmount = widget.category.goalAmount;
  }

  double get progressPercentage {
    if (!isSavingsCategory || goalAmount == null || goalAmount == 0) return 0;
    return amount / goalAmount!;
  }

  void _handleSave() {
    // Implement save logic
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save to Goal'),
        content: TextField(
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount to save',
            prefixText: '\$',
          ),
          onSubmitted: (value) {
            final amount = double.tryParse(value);
            if (amount != null && amount > 0) {
              setState(() {
                this.amount += amount;
              });
              // Update in database/state management
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Get input value and update
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _handleWithdraw() {
    // Implement withdraw logic
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw from Goal'),
        content: TextField(
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount to withdraw',
            prefixText: '\$',
          ),
          onSubmitted: (value) {
            final amount = double.tryParse(value);
            if (amount != null && amount > 0 && amount <= this.amount) {
              setState(() {
                this.amount -= amount;
              });
              // Update in database/state management
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Get input value and update
              Navigator.of(context).pop();
            },
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
  }

  void _handleDeleteGoal() {
    // Implement delete goal logic
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content:
            const Text('Are you sure you want to delete this savings goal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Delete goal logic
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Return to previous screen
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete',
                style: TextStyle(color: Colors.red, fontSize: 18)),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeCategoryDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Center(
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_balance_wallet, size: 24),
                    SizedBox(width: 10),
                    Text('Available Amount',
                        style: TextStyle(fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${amount.toStringAsFixed(2)}',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(color: Colors.blue),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          _buildFreeActions(),
        ],
      ),
    );
  }

  Widget _buildCategoryDetails() {
    final percentage = (progressPercentage * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.home, size: 16),
                        SizedBox(width: 10),
                        Text('Savings Amount'),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 30),
                      child: Text(
                        '/${amount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Container(
                  height: 50,
                  width: 1,
                  color: Colors.black12,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.flag, size: 16),
                        SizedBox(width: 10),
                        Text('Goal Amount'),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 30),
                      child: Text(
                        '${goalAmount?.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isSavingsCategory) ...[
            const SizedBox(height: 32),
            _buildCircularProgress(percentage),
            const SizedBox(height: 40),
            _buildActions(),
          ] else ...[
            const SizedBox(height: 40),
            _buildFreeActions(),
          ]
        ],
      ),
    );
  }

  Widget _buildCircularProgress(int percentage) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 150,
                width: 150,
                child: CircularProgressIndicator(
                  value: progressPercentage,
                  strokeWidth: 10,
                  backgroundColor: Colors.grey.shade300,
                  color: Colors.blue,
                ),
              ),
              Column(
                children: [
                  Text(
                    "You're",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    "$percentage%",
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    "there! Keep it up!",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFreeActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        SizedBox(
          width: 120,
          child: TextButton.icon(
            onPressed: _handleWithdraw,
            icon: const Icon(Icons.remove_circle_outline),
            label: const Text('Withdraw'),
          ),
        ),
        SizedBox(
          width: 120,
          child: TextButton.icon(
            onPressed: _handleDeleteGoal,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions',
          style: TtextTheme.lightText.headlineMedium,
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Row(
                children: [
                  Text('Save'),
                  Icon(Icons.save_alt_outlined, size: 18),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _handleWithdraw,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
              ),
              child: const Row(
                children: [
                  Icon(Icons.account_balance_wallet, size: 20),
                  SizedBox(width: 4),
                  Text(
                    'Withdraw',
                    style: TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _handleDeleteGoal,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.delete,
                    size: 20,
                    color: Colors.red,
                  ),
                  SizedBox(width: 4),
                  Text('Delete Goal'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Hero(
              tag: widget.heroTag,
              child: Center(
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  child: Text(
                    widget.category.name.substring(0, 1),
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            isSavingsCategory
                ? _buildCategoryDetails()
                : _buildFreeCategoryDetails(),
          ],
        ),
      ),
    );
  }
}
