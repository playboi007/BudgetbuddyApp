import 'package:budgetbuddy_app/services/category_provider.dart';
import 'package:budgetbuddy_app/widgets/category%20widgets/category_type_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
//import 'package:percent_indicator/percent_indicator.dart';
import 'categories_page.dart';
import '../data models/budget_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:budgetbuddy_app/widgets/home_page_widgets/home_widgets.dart';
import 'package:budgetbuddy_app/widgets/category widgets/add_category_card.dart';
import 'package:budgetbuddy_app/widgets/category widgets/category_form_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<BudgetCategory> categories = [];
  // ignore: unused_field
  bool _isLoading = true;
  String? _error;

  @override
  //fetches category data from firestore on initialization
  void initState() {
    super.initState();
    _loadCategories();
  }

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
              onSave: (newCategory) {
                setState(() {
                  categories.add(newCategory);
                });
                Navigator.pop(context);
              },
            ));
  }

//this builds the list view
  Widget _buildCategorySection() {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 1,
        separatorBuilder: (context, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == categories.length) {
            return _buildAddCategoryCard();
          }
          //function call to home_widgets.dart
          return BuildCategoryCard(category: categories[index]);
        },
      ),
    );
  }

  Widget _buildAddCategoryCard() {
    return AddCategoryCard(
      onTap: _showCategoryTypeDialog,
      isHorizontal: true,
    );
  }

  //this is the code that builds the categories cards
  // BuildCategoryCard(category: categories[index]); // Removed incorrect declaration

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              //balance and categories widget
              BalanceAndCategories(),

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Budget Categories',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(213, 33, 149, 243)),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_forward,
                      color: Colors.blue,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CategoriesPage()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildCategorySection(),

              const SizedBox(height: 20),
              TransactionView(),

              //logout button
              FloatingActionButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!mounted) return;
                  Navigator.pushReplacementNamed(context, '/');
                },
                child: const Icon(Icons.logout),
              )
            ],
          ),
        ),
      ),
    );
  }
}
