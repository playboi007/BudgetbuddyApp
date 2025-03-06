import 'package:budgetbuddy_app/services/category_provider.dart';
import 'package:budgetbuddy_app/states/analytics_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:budgetbuddy_app/firebase_options.dart';
import 'package:provider/provider.dart';
import 'Mobile UI/login_screen.dart';
import 'utils/theme/theme.dart';
import 'widgets/bottom_navbar.dart';

//-----entry point of flutter app-----
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //signs out any persisted user 1st
  //await FirebaseAuth.instance.signOut();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
      ChangeNotifierProvider(create: (context) => CategoryProvider()),
    ],
    child: const BudgetBuddyApp(),
  ));
}

class BudgetBuddyApp extends StatelessWidget {
  const BudgetBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Budget Buddy',
      themeMode: ThemeMode.system,
      theme: TappTheme.lightTheme,
      darkTheme: TappTheme.darkTheme,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoginScreen();
          }

          if (snapshot.connectionState == ConnectionState.active) {
            final user = snapshot.data;
            if (user == null) {
              return const LoginScreen();
            } else {
              return const BottomNavigation();
            }
          }
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        },
      ),
    );
  }
}
