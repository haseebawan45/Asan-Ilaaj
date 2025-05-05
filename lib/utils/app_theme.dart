import 'package:flutter/material.dart';

// Centralized color scheme for the entire app
class AppTheme {
  // Primary Colors
  static const Color primaryPink = Color(0xFFFF3F80);
  static const Color primaryTeal = Color(0xFF30A9C7);
  
  // Light variants for backgrounds
  static const Color lightPink = Color(0xFFFFE6F0);
  static const Color lightTeal = Color(0xFFE6F7FB);
  static const Color veryLightPink = Color(0xFFFFF5F9);
  static const Color veryLightTeal = Color(0xFFF0FBFF);
  
  // Dark variants for emphasis
  static const Color darkPink = Color(0xFFD62E67);
  static const Color darkTeal = Color(0xFF1E86A1);
  
  // Neutral colors
  static const Color darkText = Color(0xFF333333);
  static const Color mediumText = Color(0xFF6F7478);
  static const Color lightText = Color(0xFF9E9E9E);
  static const Color background = Color(0xFFF9F9F9);
  static const Color divider = Color(0xFFEEEEEE);
  
  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF2196F3);
  
  // Function to get gradient based on context
  static LinearGradient getPrimaryGradient({bool reversed = false}) {
    return LinearGradient(
      begin: reversed ? Alignment.topRight : Alignment.topLeft,
      end: reversed ? Alignment.bottomLeft : Alignment.bottomRight,
      colors: [
        primaryPink,
        primaryTeal,
      ],
    );
  }
  
  // Get theme based on user type (doctor uses pink accent, patient uses teal accent)
  static Color getPrimaryColor(bool isDoctor) {
    return isDoctor ? primaryPink : primaryTeal;
  }
  
  static Color getSecondaryColor(bool isDoctor) {
    return isDoctor ? primaryTeal : primaryPink;
  }
  
  static Color getLightColor(bool isDoctor) {
    return isDoctor ? lightPink : lightTeal;
  }
  
  static Color getVeryLightColor(bool isDoctor) {
    return isDoctor ? veryLightPink : veryLightTeal;
  }
  
  // Get complete ThemeData for the app
  static ThemeData getThemeData() {
    return ThemeData(
      primaryColor: primaryTeal,
      colorScheme: ColorScheme.light(
        primary: primaryTeal,
        secondary: primaryPink,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        surface: Colors.white,
        background: background,
        error: error,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: darkText,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryTeal),
        titleTextStyle: TextStyle(
          color: darkText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTeal,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryTeal,
          side: BorderSide(color: primaryTeal),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryTeal,
          textStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryTeal, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: error, width: 1),
        ),
        hintStyle: TextStyle(color: lightText),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      scaffoldBackgroundColor: background,
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryTeal;
          }
          return null;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryTeal;
          }
          return null;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryTeal;
          }
          return null;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryTeal.withOpacity(0.5);
          }
          return null;
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryTeal,
        unselectedItemColor: mediumText,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      tabBarTheme: TabBarTheme(
        labelColor: primaryTeal,
        unselectedLabelColor: mediumText,
        indicator: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: primaryTeal,
              width: 2,
            ),
          ),
        ),
      ),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
} 