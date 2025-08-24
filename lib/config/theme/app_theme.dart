import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData getAppTheme() => ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF672BB6), // Rojo principal
          onPrimary: Colors.white, // Texto/blanco sobre fondo rojo
          secondary: Color(0xFF8F8F8F), // Gris para elementos secundarios
          onSecondary: Colors.white, // Texto/blanco sobre fondo secundario
          surface: Colors.white, // Fondo general
          onSurface: Color(0xFF333333), // Texto oscuro sobre fondo claro
          error: Color(0xFFD32F2F), // Rojo para errores
          onError: Colors.white, // Texto blanco sobre fondo de error
          primaryContainer: Color(0xFFFFCDD2), // Variante clara del primario
          onPrimaryContainer:
              Color.fromARGB(255, 103, 43, 182), // Texto oscuro sobre variante clara
          secondaryContainer:
              Color(0xFFC7C7C7), // Variante clara del secundario (gris claro)
          onSecondaryContainer:
              Color(0xFF424242), // Texto oscuro sobre variante clara
          outline: Color(0xFF8F8F8F), // Gris para bordes o delineaciones
        ),

        // Estilo de AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 103, 43, 182), // Rojo principal
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Estilo de botones elevados
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 103, 43, 182), // Rojo principal
            foregroundColor: Colors.white, // Texto blanco
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // Estilo de texto
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.grey[800], fontSize: 16),
          bodyMedium: TextStyle(color: Colors.grey[600], fontSize: 14),
          titleLarge: const TextStyle(
            color: Color.fromARGB(255, 103, 43, 182), // Rojo principal
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Estilo de campos de texto
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding:
              const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color.fromARGB(255, 103, 43, 182), // Rojo principal
            ),
          ),
          labelStyle: TextStyle(color: Colors.grey[700]),
          hintStyle: TextStyle(color: Colors.grey[400]),
        ),

        // Estilo de ToggleButtons
        toggleButtonsTheme: ToggleButtonsThemeData(
          borderColor: const Color(0xFF8F8F8F), // Gris
          selectedBorderColor: const Color(0xFF8F8F8F), // Gris
          selectedColor: Colors.white,
          fillColor: const Color(0xFF8F8F8F), // Gris
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          borderRadius: BorderRadius.circular(20),
        ),
      );
}
