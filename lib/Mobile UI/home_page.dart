import 'package:budgetbuddy_app/services/category_provider.dart';
import 'package:budgetbuddy_app/services/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
//import 'package:percent_indicator/percent_indicator.dart';
import 'categories_page.dart';
import '../data models/budget_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:budgetbuddy_app/widgets/home_page_widgets/home_widgets.dart';

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
  final ScrollController _scrollController = ScrollController();
  String _userName = '';

  @override
  //fetches category data from firestore on initialization
  void initState() {
    super.initState();
    _loadCategories();
    _loadUserName();
    // Initialize notifications
    Future.microtask(() =>
        Provider.of<NotificationProvider>(context, listen: false)
            .fetchNotifications());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userName = user.displayName ?? 'User';
      });
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
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 70.0,
            floating: false,
            pinned: true,
            snap: false,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.zero,
              title: UserAppbar(name: _userName),
              expandedTitleScale: 1.0,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BalanceAndCategories(),

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
                          MaterialPageRoute(
                              builder: (context) => CategoriesPage()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const CategoryList(),

                  const SizedBox(height: 20),
                  const TransactionView(),

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
        ],
      ),
    );
  }
}
