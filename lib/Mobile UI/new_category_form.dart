import 'package:flutter/material.dart';
//import 'package:budgetbuddy_app/states/budget_states.dart';
import 'package:budgetbuddy_app/data models/budget_models.dart';
import 'package:budgetbuddy_app/utils/constants/text_strings.dart';
import 'package:budgetbuddy_app/utils/constants/enums.dart';

class NewCategoryForm extends StatefulWidget {
  final String categoryType;
  final Function(BudgetCategory) onSave;
  final Map<String, dynamic>? featuredGoal;
  //final Function(Map<String, String>) onSave;

  const NewCategoryForm({
    super.key,
    required this.categoryType,
    required this.onSave,
    this.featuredGoal,
  });

  @override
  _NewCategoryFormState createState() => _NewCategoryFormState();
}

class _NewCategoryFormState extends State<NewCategoryForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _startAmountController = TextEditingController();
  final _goalAmountController = TextEditingController();
  bool _isLocked = false;
  DateTime? _reminderDate;
  ReminderFrequency _reminderFrequency = ReminderFrequency.none;

  @override
  void initState() {
    super.initState();
    // Populate form fields if a featured goal is provided
    if (widget.featuredGoal != null) {
      _nameController.text = widget.featuredGoal!['name'] ?? '';
      if (widget.featuredGoal!['targetAmount'] != null) {
        _goalAmountController.text =
            widget.featuredGoal!['targetAmount'].toString();
      }
      // Set category type to Savings for featured goals
      if (widget.categoryType == 'Savings' &&
          widget.featuredGoal!['description'] != null) {
        // You could add more initialization here if needed
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startAmountController.dispose();
    _goalAmountController.dispose();
    super.dispose();
  }

  Future<void> _selectReminderDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _reminderDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select reminder date',
    );
    if (picked != null && picked != _reminderDate) {
      setState(() {
        _reminderDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.featuredGoal != null 
        ? 'Create Goal from Template' 
        : 'Create New ${widget.categoryType} Goal';
        
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return TextStrings.savingsGoalNew;
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
                  return TextStrings.savingsAmount;
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
                  return TextStrings.savingsGoalAmount;
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
            const SizedBox(height: 10),
            ListTile(
              title: const Text('Set Reminder Date'),
              subtitle: Text(_reminderDate == null
                  ? 'No reminder set'
                  : 'Reminder on: ${_reminderDate!.day}/${_reminderDate!.month}/${_reminderDate!.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectReminderDate,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<ReminderFrequency>(
              decoration: const InputDecoration(
                labelText: 'Reminder Frequency',
                border: OutlineInputBorder(),
              ),
              value: _reminderFrequency,
              items: ReminderFrequency.values.map((frequency) {
                String displayName = '';
                switch (frequency) {
                  case ReminderFrequency.weekly:
                    displayName = 'Weekly';
                    break;
                  case ReminderFrequency.biWeekly:
                    displayName = 'Bi-Weekly';
                    break;
                  case ReminderFrequency.monthly:
                    displayName = 'Monthly';
                    break;
                  case ReminderFrequency.none:
                    displayName = 'No Recurring Reminder';
                    break;
                }
                return DropdownMenuItem<ReminderFrequency>(
                  value: frequency,
                  child: Text(displayName),
                );
              }).toList(),
              onChanged: (ReminderFrequency? newValue) {
                if (newValue != null) {
                  setState(() {
                    _reminderFrequency = newValue;
                  });
                }
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
                  return TextStrings.savingsAmount;
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
                  reminderDate: _reminderDate,
                  reminderFrequency: _reminderFrequency,
                );
                widget.onSave(newCategory);
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    ),
    )
    );
  }
  }

