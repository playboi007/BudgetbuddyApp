import 'package:flutter/material.dart';
//import 'package:budgetbuddy_app/states/budget_states.dart';
import 'package:budgetbuddy_app/data models/budget_models.dart';

class NewCategoryForm extends StatefulWidget {
  final String categoryType;
  final Function(BudgetCategory) onSave;
  //final Function(Map<String, String>) onSave;

  const NewCategoryForm(
      {super.key, required this.categoryType, required this.onSave});

  @override
  _NewCategoryFormState createState() => _NewCategoryFormState();
}

class _NewCategoryFormState extends State<NewCategoryForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _startAmountController = TextEditingController();
  final _goalAmountController = TextEditingController();
  bool _isLocked = false;

  @override
  void dispose() {
    _nameController.dispose();
    _startAmountController.dispose();
    _goalAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please provide a name for the category';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          if (widget.categoryType == "Savings") ...[
            TextFormField(
              controller: _startAmountController,
              decoration: InputDecoration(labelText: 'Start Amount'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount to start with';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _goalAmountController,
              decoration: const InputDecoration(labelText: 'Goal Amount'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a target amount you want to achieve';
                }
                return null;
              },
            ),
            CheckboxListTile(
              title: Text('Lock till target amount'),
              value: _isLocked,
              onChanged: (value) {
                setState(() {
                  _isLocked = value!;
                });
              },
            ),
          ],
          const SizedBox(height: 20),
          if (widget.categoryType == "Free") ...[
            TextFormField(
              controller: _startAmountController,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount to start with';
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final newCategory = BudgetCategory(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: _nameController.text,
                  amount: double.parse(_startAmountController.text),
                  categoryType: widget.categoryType,
                  goalAmount: widget.categoryType == 'Savings'
                      ? double.parse(_goalAmountController.text)
                      : null,
                  isLocked: _isLocked,
                  createdAt: DateTime.now(),
                );
                widget.onSave(newCategory);
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }
}
