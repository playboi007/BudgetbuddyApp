import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budgetbuddy_app/services/category_provider.dart';
import 'package:budgetbuddy_app/services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeaturedGoalsScreen extends StatelessWidget {
  const FeaturedGoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Featured Goals')),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseService().getFeaturedGoals(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No featured goals available'));
          }
          return _buildGrid(snapshot.data!.docs);
        },
      ),
    );
  }

  Widget _buildGrid(List<QueryDocumentSnapshot> goals) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: goals.length,
      itemBuilder: (context, index) => _buildGoalCard(context, goals[index]),
    );
  }

  Widget _buildGoalCard(BuildContext context, QueryDocumentSnapshot goal) {
    final data = goal.data() as Map<String, dynamic>;
    return GestureDetector(
      //onTap: () => _showGoalDetails(context, data),
      onTap: () => _showGoalDetails(context, data as DocumentSnapshot<Object?>),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: NetworkImage(data['imageUrl']),
            fit: BoxFit.cover,
          ),
        ),
        child: _buildGradientOverlay(data),
      ),
    );
  }

  Widget _buildGradientOverlay(Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['title'],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              'Ksh ${data['recommendedAmount']}',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _showGoalDetails(BuildContext context, DocumentSnapshot goal) {
    final data = goal.data() as Map<String, dynamic>;
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(goal['title'], style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 16),
            Text(goal['description']),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.read<CategoryProvider>().addFeaturedGoal({
                  'name': data['title'],
                  'goalAmount': data['recommendedAmount'],
                });
                //Navigator.pop(context);
              },
              child: const Text('Add to My Categories'),
            ),
          ],
        ),
      ),
    );
  }
}
