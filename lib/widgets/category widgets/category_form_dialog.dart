import 'package:flutter/material.dart';
import 'package:budgetbuddy_app/Mobile UI/new_category_form.dart';
import 'package:budgetbuddy_app/data models/budget_models.dart';

class CategoryFormDialog extends StatelessWidget {
  final String categoryType;
  final Function(BudgetCategory) onSave;

  const CategoryFormDialog({
    super.key,
    required this.categoryType,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: screenSize.width > 600 ? 500 : screenSize.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: screenSize.height * 0.85,
          maxWidth: screenSize.width > 600 ? 500 : screenSize.width * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Text('Create New Category',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: NewCategoryForm(
                categoryType: categoryType,
                onSave: onSave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
