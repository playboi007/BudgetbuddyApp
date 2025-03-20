import 'package:budgetbuddy_app/utils/theme/text_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  _CategoriesPageState createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  bool _isLoading = true;
  String? _error;
  void _showCategoryTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => CategoryTypeDialog(
        onCategoryTypeSelected: (type) => _showNewCategoryDialog(type),
      ),
    );
  }

  void _showNewCategoryDialog(String categoryType) {
    showDialog(
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

  Widget _buildAddCategoryCard() {
    return AddCategoryCard(
      onTap: _showCategoryTypeDialog,
      isHorizontal: false,
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
      final providerCategories = categoryProvider.categories;

      //this converts each map into a budgetcategory model.
      final categories = providerCategories.map((catMap) {
        return BudgetCategory(
          id: catMap['id'] ?? '',
          name: catMap['name'] ?? '',
          amount: (catMap['amount'] ?? 0).toDouble(),
          categoryType: catMap['categoryType'] ?? '',
          goalAmount: (catMap['goalAmount'] ?? 0).toDouble(),
          isLocked: catMap['isLocked'] ?? false,
          createdAt: (catMap['createdAt'] as Timestamp).toDate(),
        );
      }).toList();
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
                        return _buildAddCategoryCard();
                      }
                      final category = categories[index];
                      return ListTile(
                        //we use the 1st letter of the category in a circle as the leading widget
                        leading: Hero(
                          tag: category
                              .name, //I use the index as a unique hero tag
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
                              Text(
                                  'Goal: Ksh ${category.goalAmount?.toStringAsFixed(2)}'),
                          ],
                        ),
                        trailing: category.categoryType == 'Savings'
                            ? Icon(
                                category.isLocked
                                    ? Icons.lock
                                    : Icons.lock_open,
                                color: category.isLocked
                                    ? Colors.red
                                    : Colors.green,
                              )
                            : null,
                        onTap: () =>
                            _showCategoryDetails(category, category.name),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
