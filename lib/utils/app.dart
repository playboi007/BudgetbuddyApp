import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:budgetbuddy_app/Mobile UI/splash_screen.dart';
import 'package:budgetbuddy_app/services/category_provider.dart';
import 'package:budgetbuddy_app/services/course_provider.dart';
import 'package:budgetbuddy_app/services/notification_provider.dart';
import 'package:budgetbuddy_app/services/transaction_provider.dart';
import 'package:budgetbuddy_app/services/theme_provider.dart';
import 'package:budgetbuddy_app/states/analytics_provider.dart';
import 'package:budgetbuddy_app/utils/theme/theme.dart';
import 'package:budgetbuddy_app/widgets/bottom_navbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static Future<void> _initialize() async {
    try {
      await Firebase.initializeApp();
      final prefs = await SharedPreferences.getInstance();
      final isFirstTime = prefs.getBool('isFirstTime') ?? true;
      if (isFirstTime) {
        await prefs.setBool('isFirstTime', false);
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialize(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => CategoryProvider()),
            ChangeNotifierProvider(create: (_) => TransactionProvider()),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
            ChangeNotifierProvider(create: (_) => CourseProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'BudgetBuddy',
                theme: TappTheme.lightTheme,
                darkTheme: TappTheme.darkTheme,
                themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
                home: StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return snapshot.hasData ? const BottomNavigation() : const SplashScreen();
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
