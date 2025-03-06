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
    return AlertDialog(
      title: const Text('Create New Category'),
      content: NewCategoryForm(
        categoryType: categoryType,
        onSave: onSave,
      ),
    );
  }
}
