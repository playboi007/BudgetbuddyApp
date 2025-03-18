import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:budgetbuddy_app/Mobile%20UI/new_category_form.dart';
import 'package:budgetbuddy_app/data%20models/budget_models.dart';

class FeaturedGoalDetailScreen extends StatelessWidget {
  final DocumentSnapshot goal;

  const FeaturedGoalDetailScreen({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    final data = goal.data() as Map<String, dynamic>;
    final String imageUrl = data['imageUrl'] ?? '';
    final String name = data['name'] ?? 'Goal';
    final String description =
        data['description'] ?? 'No description available';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: Theme.of(context).primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
                ),
                overflow: TextOverflow.ellipsis,
              ),
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Hero(
                tag: 'goal-image-${goal.id}',
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (data['targetAmount'] != null) ...[
                    const Text(
                      'Target Amount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ksh ${data['targetAmount']}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (data['timeframe'] != null) ...[
                    const Text(
                      'Timeframe',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data['timeframe'],
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 40),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Theme.of(context).primaryColor,
                      ),
                      onPressed: () =>
                          _navigateToCategoryCreation(context, data),
                      child: const Text(
                        'Create Goal from Template',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToCategoryCreation(
      BuildContext context, Map<String, dynamic> goalData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewCategoryForm(
          categoryType: 'Savings',
          featuredGoal: goalData,
          onSave: (BudgetCategory category) {
            // Handle saving the new category
            Navigator.pop(context);
            Navigator.pop(context); // Return to featured goals screen
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${category.name} goal created successfully!'),
              ),
            );
          },
        ),
      ),
    );
  }
}
