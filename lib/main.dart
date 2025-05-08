import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:budgetbuddy_app/firebase_options.dart';
import 'package:budgetbuddy_app/utils/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Entry point of the Flutter application
Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Pre-load critical data
    await _preloadCriticalData();

    runApp(const MyApp());
  }, (error, stack) {
    // Handle any errors that occur during initialization
    debugPrint('Error during initialization: $error');
    debugPrint(stack.toString());
  });
}

Future<void> _preloadCriticalData() async {
  // Load any critical data needed before app starts
  // This runs in parallel
  await Future.wait([
    SharedPreferences.getInstance(),
    // Add other critical initialization here
  ]);
}
