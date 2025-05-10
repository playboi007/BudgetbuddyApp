import 'package:budgetbuddy_app/utils/theme/text_theme.dart';
import 'package:flutter/material.dart';
import 'package:budgetbuddy_app/data models/budget_models.dart';
import 'package:provider/provider.dart';
import 'package:budgetbuddy_app/services/category_provider.dart';
import 'package:budgetbuddy_app/Mobile UI/featured_goals_screen.dart';
import 'package:budgetbuddy_app/widgets/category widgets/add_category_card.dart';
import 'package:budgetbuddy_app/widgets/category widgets/category_details_dialog.dart';
import 'package:budgetbuddy_app/widgets/category widgets/category_form_dialog.dart';
import 'package:budgetbuddy_app/widgets/category widgets/category_type_dialog.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  CategoriesPageState createState() => CategoriesPageState();
}

class CategoriesPageState extends State<CategoriesPage> {
  bool _isLoading = true;
  String? _error;

  void _showCategoryTypeDialog() {
    showDialog<void>(
      // Explicitly type the dialog return
      context: context,
      builder: (context) => CategoryTypeDialog(
        onCategoryTypeSelected:
            _showNewCategoryDialog, // Pass callback directly
      ),
    );
  }

  void _showNewCategoryDialog(String categoryType) {
    showDialog<void>(
      // Explicitly type the dialog return
      context: context,
      builder: (context) => CategoryFormDialog(
        categoryType: categoryType,
        onSave: (newCategory) async {
          try {
            await Provider.of<CategoryProvider>(context, listen: false)
                .addCategory({
              'name': newCategory.name,
              'amount': newCategory.amount,
              'categoryType': newCategory.categoryType,
              'goalAmount': newCategory.goalAmount,
              'isLocked': newCategory.isLocked,
            });

            if (!mounted) return;
            Navigator.pop(context);
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('error adding category: $e')),
            );
          }
        },
      ),
    );
  }

  void _showCategoryDetails(BudgetCategory category, String heroTag) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CategoryDetailsDialog(category: category, heroTag: heroTag),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  //this method loads categories from firebase
  //updated
  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      //we'll use state provider hapa kuload categories
      await Provider.of<CategoryProvider>(context, listen: false)
          .loadCategories();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, child) {
        final categories = categoryProvider.categoryModels;

        if (_isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_error != null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: $_error'),
                  ElevatedButton(
                    onPressed: _loadCategories,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text("Categories"),
            foregroundColor: Colors.blue,
          ),
          body: RefreshIndicator(
            onRefresh: _loadCategories,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const FeaturedGoalsScreen()),
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Colors.blue, Colors.purple]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Discover Featured Goals',
                          style: TtextTheme.lightText.titleMedium,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: categories.length + 1,
                      itemBuilder: (context, index) {
                        if (index == categories.length) {
                          return AddCategoryCard(
                            onTap:
                                _showCategoryTypeDialog, // Pass callback directly without wrapper
                            isHorizontal: false,
                          );
                        }
                        return CategoryListItem(
                          category: categories[index],
                          onTap: _showCategoryDetails,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// New widget for list items
class CategoryListItem extends StatelessWidget {
  const CategoryListItem({
    super.key,
    required this.category,
    required this.onTap,
  });

  final BudgetCategory category;
  final Function(BudgetCategory, String) onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Hero(
        tag: category.name,
        child: CircleAvatar(
          child: Text(category.name.substring(0, 1)),
        ),
      ),
      title: Text(category.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ksh ${category.amount.toStringAsFixed(2)}'),
          if (category.categoryType == 'savings')
            Text('Goal: Ksh ${category.goalAmount?.toStringAsFixed(2)}'),
        ],
      ),
      trailing: category.categoryType == 'Savings'
          ? Icon(
              category.isLocked ? Icons.lock : Icons.lock_open,
              color: category.isLocked ? Colors.red : Colors.green,
            )
          : null,
      onTap: () => onTap(category, category.name),
    );
  }
}
