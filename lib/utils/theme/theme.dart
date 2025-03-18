import 'package:budgetbuddy_app/utils/theme/bottomsheet_theme.dart';
import 'package:budgetbuddy_app/utils/theme/text_theme.dart';
import 'package:budgetbuddy_app/utils/theme/elevated_button_theme.dart';
import 'package:budgetbuddy_app/utils/theme/appBar_theme.dart';
import 'package:flutter/material.dart';

class TappTheme {
  TappTheme._();

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: Colors.blue,
    //fontFamily: 'GarotaSans',
    scaffoldBackgroundColor: Colors.white,
    textTheme: TtextTheme.lightText,
    colorScheme: ColorScheme.light(
      primary: Colors.blue,
      secondary: Colors.blueAccent,
    ),
    elevatedButtonTheme: TElevatedtheme.lightElevatedThemeData,
    appBarTheme: TAppbarTheme.lightAppbarTheme,
    bottomSheetTheme: TBottomSheetTheme.lightBottomSheetTheme,
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: Colors.blue,
    //fontFamily: 'GarotaSans',
    scaffoldBackgroundColor: Colors.black,
    textTheme: TtextTheme.darktText,
    colorScheme: ColorScheme.dark(
      primary: Colors.blue,
      secondary: Colors.blueAccent,
    ),
    elevatedButtonTheme: TElevatedtheme.darkElevatedThemeData,
    appBarTheme: TAppbarTheme.darkAppbarTheme,
    bottomSheetTheme: TBottomSheetTheme.darkBottomSheetTheme,
  );
}
