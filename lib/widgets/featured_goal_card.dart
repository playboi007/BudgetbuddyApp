import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FeaturedGoalCard extends StatelessWidget {
  final DocumentSnapshot goal;
  final VoidCallback onTap;

  const FeaturedGoalCard({super.key, required this.goal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final data = goal.data() as Map<String, dynamic>;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Hero image
          Hero(
            tag: 'goal-image-${goal.id}',
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: NetworkImage(data['imageUrl']),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent
                ],
              ),
            ),
          ),
          // Text content
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                data['name'],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
