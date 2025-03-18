import 'package:flutter/material.dart';

class CategoryTypeDialog extends StatelessWidget {
  final Function(String) onCategoryTypeSelected;

  const CategoryTypeDialog({
    super.key,
    required this.onCategoryTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('What type would you like?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            child: const Text('Free'),
            onPressed: () {
              Navigator.pop(context);
              onCategoryTypeSelected('Free');
            },
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            child: const Text('Savings'),
            onPressed: () {
              Navigator.pop(context);
              onCategoryTypeSelected('Savings');
            },
          ),
        ],
      ),
    );
  }
}
