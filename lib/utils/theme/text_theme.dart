import 'package:flutter/material.dart';

class TtextTheme {
  TtextTheme._();

  static TextTheme lightText = TextTheme(
    headlineLarge: const TextStyle().copyWith(
        fontSize: 32.0, fontWeight: FontWeight.bold, color: Colors.black),
    headlineMedium: const TextStyle().copyWith(
        fontSize: 24.0, fontWeight: FontWeight.w600, color: Colors.black87),
    titleLarge: const TextStyle().copyWith(
        fontSize: 20.0, fontWeight: FontWeight.w600, color: Colors.black87),
    titleMedium: const TextStyle().copyWith(
        fontSize: 18.0, fontWeight: FontWeight.w500, color: Colors.black87),
    titleSmall: const TextStyle().copyWith(
        fontSize: 18.0, fontWeight: FontWeight.w400, color: Colors.black87),
    bodyLarge: const TextStyle().copyWith(
        fontWeight: FontWeight.w500, fontSize: 16, color: Colors.black87),
    bodyMedium: const TextStyle().copyWith(
        fontWeight: FontWeight.normal, fontSize: 12, color: Colors.black87),

    //other text
    //lesson_page

  );

  static TextTheme darktText = TextTheme(
    headlineLarge: const TextStyle().copyWith(
        fontSize: 32.0, fontWeight: FontWeight.bold, color: Colors.white),
    headlineMedium: const TextStyle().copyWith(
        fontSize: 24.0, fontWeight: FontWeight.w500, color: Colors.white),
    titleLarge: const TextStyle().copyWith(
        fontSize: 18.0, fontWeight: FontWeight.w600, color: Colors.white),
    titleMedium: const TextStyle().copyWith(
        fontSize: 18.0, fontWeight: FontWeight.w500, color: Colors.white),
    titleSmall: const TextStyle().copyWith(
        fontSize: 18.0, fontWeight: FontWeight.w400, color: Colors.white),
    bodyLarge: const TextStyle().copyWith(
        fontWeight: FontWeight.w500, fontSize: 12, color: Colors.white),
    bodyMedium: const TextStyle().copyWith(
        fontWeight: FontWeight.normal, fontSize: 12, color: Colors.white),
  );
}
