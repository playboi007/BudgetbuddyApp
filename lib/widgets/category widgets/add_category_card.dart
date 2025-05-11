import 'package:flutter/material.dart';

class AddCategoryCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool isHorizontal;

  const AddCategoryCard({
    super.key,
    required this.onTap,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isHorizontal) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 160,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: Colors.blue, size: 32),
              SizedBox(height: 8),
              Text('New Category',
                  style: TextStyle(color: Colors.blue, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Colors.grey[200],
        child: const ListTile(
          title: Text(
            'New category',
            style: TextStyle(color: Colors.blue),
          ),
          trailing: Icon(
            Icons.add,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }
}
