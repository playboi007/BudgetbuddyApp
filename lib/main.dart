import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:budgetbuddy_app/firebase_options.dart';
import 'package:budgetbuddy_app/utils/app.dart';

//-----entry point of flutter app-----
void main() async {
  //-----initializing firebase-----
  //add widgtes bidding
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
