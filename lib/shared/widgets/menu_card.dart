import 'package:flutter/material.dart';

class MenuCard {
  final String userRole; // 🔹 Recibe el rol del usuario

  MenuCard({required this.userRole});

  List<Map<String, dynamic>> getMenuItems() {
    if (userRole == "PROFESOR" || userRole == "ADMIN") {
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
    }else if (userRole == "ASESOR" ) {
      return [
      
          {
          "icon": Icons.note, // 🔹 Icono más intuitivo para escanear
          "text": "Calificar atención", // 🔹 Texto más claro y directo
          "route": "/home/calificacion",
          "description": "Calificar atencion cliente", // 🔹 Descripción más precisa
          "highlight":
              true // 🔹 Podemos usar esto para aplicar un estilo especial en la UI
        }
      ];
    } else if(userRole == "ESTUDIANTE") {
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
    }else if(userRole == "REPRESENTANTE"){
   return [
  {
    "icon":Icons.description_outlined,
    "text": "Asistencia",
    "route": "/home/asistencia",
    "description": "Descarga y consulta la asistencia de tu hijo/a",
    "highlight": true,
  },
  {
    "icon": Icons.grade_outlined,
    "text": "Notas",
    "route": "/home/notas",
    "description": "Revisa y descarga las calificaciones de tu hijo/a",
    "highlight": false,
  },
  {
    "icon": Icons.psychology_outlined,
    "text": "Orientación vocacional",
    "route": "/home/orientacion",
    "description": "Accede al reporte vocacional de tu hijo/a",
    "highlight": false,
  },
];


    }else {
      return [];
    }
  }
}
