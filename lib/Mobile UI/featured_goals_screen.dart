import 'package:budgetbuddy_app/utils/constants/text_strings.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:budgetbuddy_app/widgets/featured_goal_card.dart';
import 'package:budgetbuddy_app/Mobile%20UI/featured_goal_detail_screen.dart';

class FeaturedGoalsScreen extends StatelessWidget {
  const FeaturedGoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(TextStrings.featCat)),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance.collection('featured_goals').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) => FeaturedGoalCard(
              goal: snapshot.data!.docs[index],
              onTap: () =>
                  _navigateToGoalDetail(context, snapshot.data!.docs[index]),
            ),
          );
        },
      ),
    );
  }

  void _navigateToGoalDetail(BuildContext context, DocumentSnapshot goal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FeaturedGoalDetailScreen(goal: goal),
      ),
    );
  }
}
