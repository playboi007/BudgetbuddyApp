import 'package:budgetbuddy_app/repositories/auth_repo.dart';
import 'package:budgetbuddy_app/services/category_provider.dart';
import 'package:flutter/material.dart';
import 'categories_page.dart';
import 'package:budgetbuddy_app/widgets/home_page_widgets/home_widgets.dart';
import 'package:budgetbuddy_app/utils/constants/colors.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthRepo, CategoryProvider>(
      builder: (context, authRepo, categoryProvider, _) {
        return Scaffold(
          appBar: UserAppbar(name: authRepo.userName),
          body:SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
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
                                  color: Appcolors.textBlueAccent),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_forward,
                                color: Appcolors.buttonBlue,
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => CategoriesPage()),
                              ), // Refresh after returning
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const CategoryList(),
                        const SizedBox(height: 20),
                        const TransactionView(),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
