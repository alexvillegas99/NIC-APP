import 'package:flutter/material.dart';

class MenuCard {
  final String userRole; // 🔹 Recibe el rol del usuario

  MenuCard({required this.userRole});

  List<Map<String, dynamic>> getMenuItems() {
    if (userRole != "ESTUDIANTE") {
      return [
        {
          "icon": Icons.qr_code_scanner, // 🔹 Icono más intuitivo para escanear
          "text": "Escanear Código QR", // 🔹 Texto más claro y directo
          "route": "/home/scan",
          "description": "Registrar Asistencias", // 🔹 Descripción más precisa
          "highlight":
              true // 🔹 Podemos usar esto para aplicar un estilo especial en la UI
        }
      ];
    } else {
      return [
        {
          "icon": Icons.badge, // 🔹 Ícono más intuitivo para QR personal
          "text": "Mi Código QR", // 🔹 Texto más corto y claro
          "route": "/home/myqr",
          "description":
              "Accede rápidamente a tu QR personal", // 🔹 Descripción opcional
          "highlight":
              true // 🔹 Podemos usar esto para aplicar un estilo especial en la UI
        }
      ];
    }
  }
}
