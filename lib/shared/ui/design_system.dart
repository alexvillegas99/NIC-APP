import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// NIC Academy Design System — Dark / Figma-aligned
class DS {
  // ─── STEAM palette (colores planos, vibrantes) ───
  static const blue     = Color(0xFF2D7FF9);
  static const purple   = Color(0xFF7C3AED);
  static const cyan     = Color(0xFF06B6D4);
  static const orange   = Color(0xFFFF8C42);
  static const green    = Color(0xFF10B981);
  static const pink     = Color(0xFFEC4899);
  static const red      = Color(0xFFEF4444);
  static const yellow   = Color(0xFFF59E0B);
  static const navy     = Color(0xFF1F2147);

  // ─── Superficies dark (Figma) ───
  static const bg       = Color(0xFF141422);
  static const card     = Color(0xFF1C1C2E);
  static const cardSoft = Color(0xFF252540);
  static const divider  = Color(0xFF2C2C45);

  // ─── Texto ───
  static const textPrimary   = Color(0xFFF0F0FF);
  static const textSecondary = Color(0xFF9090B0);
  static const textOnColor   = Colors.white;

  // ─── Estado ───
  static const success = green;
  static const error   = red;
  static const warning = yellow;
  static const info    = cyan;

  // ─── Gradiente NIC (SOLO para splash, welcome, headers principales) ───
  static const gradientColors = [
    Color(0xFF237EE0),
    Color(0xFF5030CF),
    Color(0xFF552CBA),
    Color(0xFF5E2695),
    Color(0xFF65227B),
    Color(0xFF691F6A),
    Color(0xFF6B1F65),
  ];

  static const nicGradient = LinearGradient(
    colors: gradientColors,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const nicGradientVertical = LinearGradient(
    colors: gradientColors,
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Aliases de compatibilidad ───
  static const primary  = purple;
  static const primary2 = purple;
  static const accent   = cyan;
  static const text     = textPrimary;
  static const textDim  = textSecondary;
  static const bgDark   = Color(0xFF0E0F16);
  static const cardDark = Color(0xFF111320);

  // ─── Tipografía (Poppins) ───
  static TextStyle poppins({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = textPrimary,
    double? height,
  }) =>
      GoogleFonts.poppins(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  static TextStyle h1 = poppins(size: 28, weight: FontWeight.w800);
  static TextStyle h2 = poppins(size: 22, weight: FontWeight.w700);
  static TextStyle h3 = poppins(size: 18, weight: FontWeight.w600);
  static TextStyle body = poppins(size: 16, weight: FontWeight.w400);
  static TextStyle bodyBold = poppins(size: 16, weight: FontWeight.w600);
  static TextStyle caption = poppins(size: 13, weight: FontWeight.w400, color: textSecondary);
  static TextStyle button = poppins(size: 16, weight: FontWeight.w600, color: Colors.white);
  static TextStyle small = poppins(size: 12, weight: FontWeight.w500, color: textSecondary);
  static TextStyle p = body;
  static TextStyle pDim = caption;

  // ─── Decoraciones flat ───
  static BoxDecoration cardDeco({bool glow = false, Color? glowColor}) => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: divider, width: 1),
        boxShadow: [
          if (glow)
            BoxShadow(
              color: (glowColor ?? purple).withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration gradientBox({double radius = 20}) => BoxDecoration(
        gradient: nicGradient,
        borderRadius: BorderRadius.circular(radius),
      );

  // ─── Botón principal flat ───
  static ButtonStyle primaryButton = ButtonStyle(
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    ),
    shape: WidgetStateProperty.all(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    elevation: WidgetStateProperty.all(0),
    backgroundColor: WidgetStateProperty.all(purple),
    foregroundColor: WidgetStateProperty.all(Colors.white),
  );

  // ─── Colores STEAM para categorías (cards, iconos, badges) ───
  static const steamColors = [blue, purple, cyan, orange, green, pink];

  static Color steamColor(int index) => steamColors[index % steamColors.length];

  /// Tint suave para fondo de icono/badge
  static Color tint(Color color) => color.withValues(alpha: 0.1);

  // ─── Assets URLs ───
  static const assetsBase = 'https://storage.googleapis.com/almacenamiento_imagenes/Nicpreu/';
  static const logoGradient = '${assetsBase}Asset37.png';
  static const logoDark = '${assetsBase}Asset38.png';
  static const logoAvatar = '${assetsBase}Asset40.png';
  static const mascot = '${assetsBase}Recursos%20adicionales/Mascota';
  static const logoWhite = '${assetsBase}Logo.png';
}

/// Botón flat principal NIC (color sólido)
class NicButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color color;
  final double? width;
  final double height;
  final IconData? icon;
  final bool isLoading;

  const NicButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color = DS.blue,
    this.width,
    this.height = 54,
    this.icon,
    this.isLoading = false,
  });

  @override
  State<NicButton> createState() => _NicButtonState();
}

class _NicButtonState extends State<NicButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isLoading ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.isLoading ? null : (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(widget.text, style: DS.button),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Botón secundario outline
class NicOutlineButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color color;
  final double? width;
  final double height;

  const NicOutlineButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color = DS.blue,
    this.width,
    this.height = 54,
  });

  @override
  State<NicOutlineButton> createState() => _NicOutlineButtonState();
}

class _NicOutlineButtonState extends State<NicOutlineButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.color.withValues(alpha: 0.3), width: 1.5),
            color: widget.color.withValues(alpha: 0.04),
          ),
          child: Center(
            child: Text(
              widget.text,
              style: DS.poppins(size: 16, weight: FontWeight.w600, color: widget.color),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mantener compatibilidad con NicGradientButton (solo para splash/welcome)
class NicGradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final double? width;
  final double height;
  final IconData? icon;

  const NicGradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.width,
    this.height = 56,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: DS.nicGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                ],
                Text(text, style: DS.button),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
