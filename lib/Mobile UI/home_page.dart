import 'package:budgetbuddy_app/services/category_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'categories_page.dart';
import '../data models/budget_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:budgetbuddy_app/widgets/home_page_widgets/home_widgets.dart';
import 'package:budgetbuddy_app/utils/constants/colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  List<BudgetCategory> categories = [];
  //ignore: unused_field
  bool _isLoading = true;
 
  // ignore: unused_field
  String? _error;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get user data from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data()?['name'] != null) {
          setState(() {
            _userName = userDoc.data()!['name'];
          });
        } else {
          setState(() {
            _userName = 'User';
          });
        }
      }
    } catch (e) {
      // Handle any errors during user data fetch
      setState(() {
        _userName = 'User';
      });
      if (kDebugMode) {
        print('Error loading user name: $e');
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: UserAppbar(name: _userName),
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
                        color: Appcolors.textBlueAccent),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_forward,
                      color: Appcolors.buttonBlue,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CategoriesPage()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              CategoryList(),
              const SizedBox(height: 20),
              TransactionView(),
            ],
          ),
        ),
      ),
    );
  }
}
