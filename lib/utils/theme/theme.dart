import 'package:budgetbuddy_app/utils/theme/bottomsheet_theme.dart';
import 'package:budgetbuddy_app/utils/theme/text_theme.dart';
import 'package:budgetbuddy_app/utils/theme/elevated_button_theme.dart';
import 'package:budgetbuddy_app/utils/theme/appBar_theme.dart';
import 'package:budgetbuddy_app/utils/constants/colors.dart';
import 'package:flutter/material.dart';

class TappTheme {
  TappTheme._();

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: Appcolors.blue,
    scaffoldBackgroundColor: Appcolors.backgroundWhite,
    textTheme: TtextTheme.lightText,
    colorScheme: ColorScheme.light(
      primary: Appcolors.blue,
      secondary: Appcolors.blue400,
      surface: Appcolors.white,
      error: Appcolors.error,
      onPrimary: Appcolors.white,
      onSecondary: Appcolors.white,
      onSurface: Appcolors.textBlack,
    
      onError: Appcolors.white,
    ),
    cardTheme: CardTheme(
      color: Appcolors.cardBackground,
      elevation: 2,
      shadowColor: Appcolors.cardShadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(
      color: Appcolors.settingsDivider,
      thickness: 1,
    ),
    elevatedButtonTheme: TElevatedtheme.lightElevatedThemeData,
    appBarTheme: TAppbarTheme.lightAppbarTheme,
    bottomSheetTheme: TBottomSheetTheme.lightBottomSheetTheme,
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Appcolors.settingsToggleActive;
        }
        return Appcolors.settingsToggleInactive;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Appcolors.settingsToggleActive.withValues(alpha: 0.5);
        }
        return Appcolors.settingsToggleInactive.withValues(alpha: 0.5);
      }),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: Appcolors.progressBlue,
      circularTrackColor: Appcolors.grey200,
    ),
    iconTheme: IconThemeData(
      color: Appcolors.blue400,
      size: 24,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: Appcolors.blue,
    scaffoldBackgroundColor: const Color(0xFF121212),
    textTheme: TtextTheme.darktText,
    colorScheme: ColorScheme.dark(
      primary: Appcolors.blue,
      secondary: Appcolors.blue400,
      surface: const Color(0xFF1E1E1E),
      error: Appcolors.error,
      onPrimary: Appcolors.white,
      onSecondary: Appcolors.white,
      onSurface: Appcolors.white,
      onError: Appcolors.white,
    ),
    cardTheme: CardTheme(
      color: Appcolors.cardBackgroundDark,
      elevation: 4,
      shadowColor: Appcolors.cardShadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(
      color: Appcolors.settingsDividerDark,
      thickness: 1,
    ),
    elevatedButtonTheme: TElevatedtheme.darkElevatedThemeData,
    appBarTheme: TAppbarTheme.darkAppbarTheme,
    bottomSheetTheme: TBottomSheetTheme.darkBottomSheetTheme,
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Appcolors.settingsToggleActiveDark;
        }
        return Appcolors.grey;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Appcolors.settingsToggleActiveDark.withValues(alpha: 0.5);
        }
        return Appcolors.grey.withValues(alpha: 0.5);
      }),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: Appcolors.blue,
      circularTrackColor: const Color(0xFF424242),
    ),
    iconTheme: IconThemeData(
      color: Appcolors.white,
      size: 24,
    ),
  );
}
