import 'package:flutter/material.dart';

class TElevatedtheme {
  TElevatedtheme._();

//light theme
  static final lightElevatedThemeData = ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
    elevation: 5,
    foregroundColor: Colors.white,
    backgroundColor: Colors.blue,
    side: const BorderSide(color: Colors.blue),
    padding: const EdgeInsets.symmetric(vertical: 18),
    textStyle: const TextStyle(
        fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    disabledBackgroundColor: Colors.grey,
    disabledForegroundColor: Colors.grey,
  ));

  //dark theme
  static final darkElevatedThemeData = ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
    elevation: 5,
    foregroundColor: Colors.white,
    backgroundColor: Colors.blue,
    side: const BorderSide(color: Colors.blue),
    padding: const EdgeInsets.symmetric(vertical: 18),
    textStyle: const TextStyle(
        fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    disabledBackgroundColor: Colors.grey,
    disabledForegroundColor: Colors.grey,
  ));
}
