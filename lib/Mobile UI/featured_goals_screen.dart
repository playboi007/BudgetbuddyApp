import 'package:budgetbuddy_app/utils/constants/text_strings.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:budgetbuddy_app/widgets/featured_goal_card.dart';
import 'package:budgetbuddy_app/Mobile%20UI/featured_goal_detail_screen.dart';

class FeaturedGoalsScreen extends StatefulWidget {
  const FeaturedGoalsScreen({super.key});

  @override
  State<FeaturedGoalsScreen> createState() => _FeaturedGoalsScreenState();
}

class _FeaturedGoalsScreenState extends State<FeaturedGoalsScreen> {
  final Stream<QuerySnapshot> _goalsStream = 
      FirebaseFirestore.instance.collection('featured_goals').snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const _FeaturedGoalsAppBar(),
      body: _FeaturedGoalsGrid(goalsStream: _goalsStream),
    );
  }
}

class _FeaturedGoalsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _FeaturedGoalsAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text(TextStrings.featCat));
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _FeaturedGoalsGrid extends StatelessWidget {
  const _FeaturedGoalsGrid({required this.goalsStream});

  final Stream<QuerySnapshot> goalsStream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: goalsStream,
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
            onTap: () => _navigateToGoalDetail(context, snapshot.data!.docs[index]),
          ),
        );
      },
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
