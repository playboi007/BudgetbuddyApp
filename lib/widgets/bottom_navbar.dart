import 'package:budgetbuddy_app/Mobile%20UI/home_page.dart';
import 'package:flutter/material.dart';
import '../Mobile UI/categories_page.dart';
import 'package:budgetbuddy_app/Mobile UI/reports_page.dart';
import 'package:budgetbuddy_app/Mobile UI/financial_education_page.dart';
import 'package:budgetbuddy_app/Mobile UI/settings_screen.dart';

//bottom navigation bar
class BottomNavigation extends StatefulWidget {
  const BottomNavigation({super.key});

  @override
  BottomNavigationState createState() => BottomNavigationState();
}

class BottomNavigationState extends State<BottomNavigation>
    with AutomaticKeepAliveClientMixin {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomePage(),
      const CategoriesPage(),
      const ReportPage(),
      const FinancialEducationPage(),
      const SettingsScreen()
    ];
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.category), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: ''),
          BottomNavigationBarItem(
              icon: Icon(Icons.cast_for_education), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: ''),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
