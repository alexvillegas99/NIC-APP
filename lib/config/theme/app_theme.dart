import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';

class AppTheme {
  static ThemeData getAppTheme() {
    final textTheme = GoogleFonts.poppinsTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      textTheme: textTheme,
      scaffoldBackgroundColor: DS.bg,
      colorScheme: const ColorScheme.dark(
        primary: DS.purple,
        onPrimary: Colors.white,
        secondary: DS.cyan,
        onSecondary: Colors.white,
        surface: DS.card,
        onSurface: DS.textPrimary,
        error: DS.red,
        onError: Colors.white,
        outline: DS.divider,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: DS.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: DS.textPrimary),
        titleTextStyle: DS.poppins(size: 18, weight: FontWeight.w600, color: DS.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DS.purple,
          foregroundColor: Colors.white,
          textStyle: DS.poppins(size: 16, weight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DS.cardSoft,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: DS.divider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: DS.purple, width: 1.5),
        ),
        labelStyle: DS.poppins(size: 14, color: DS.textSecondary),
        hintStyle: DS.poppins(size: 14, color: DS.textSecondary),
      ),
      cardTheme: CardThemeData(
        color: DS.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: DS.divider, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: DS.divider,
        thickness: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: DS.card,
        selectedItemColor: DS.purple,
        unselectedItemColor: DS.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: DS.poppins(size: 11, weight: FontWeight.w600),
        unselectedLabelStyle: DS.poppins(size: 11),
      ),
    );
  }
}
