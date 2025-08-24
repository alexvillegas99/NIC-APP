// lib/shared/ui/design_system.dart
import 'package:flutter/material.dart';

class DS {
  // Colores base (mockup style)
  static const bg        = Color(0xFF0E0F16);
  static const card      = Color(0xFF111320);
  static const cardSoft  = Color(0xFF16182A);
  static const primary   = Color(0xFF7C3AED);
  static const primary2  = Color(0xFF4A00E0);
  static const accent    = Color(0xFFB388FF);
  static const text      = Color(0xFFEDEDED);
  static const textDim   = Color(0xFF9EA3B0);
  static const success   = Color(0xFF22C55E);

  static BoxDecoration cardDeco({bool glow = false}) => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(16),
    border: glow ? Border.all(color: primary.withOpacity(0.35), width: 1.2) : null,
    boxShadow: [
      if (glow)
        BoxShadow(
          color: primary.withOpacity(0.20),
          blurRadius: 16,
          spreadRadius: 1,
          offset: const Offset(0, 6),
        ),
      const BoxShadow(
        color: Colors.black26,
        blurRadius: 10,
        offset: Offset(0, 6),
      ),
    ],
  );

  static TextStyle h1 = const TextStyle(
    color: text, fontSize: 22, fontWeight: FontWeight.w800);
  static TextStyle h2 = const TextStyle(
    color: text, fontSize: 18, fontWeight: FontWeight.w700);
  static TextStyle p  = const TextStyle(
    color: text, fontSize: 14, fontWeight: FontWeight.w500);
  static TextStyle pDim = const TextStyle(
    color: textDim, fontSize: 12, fontWeight: FontWeight.w500);
}
