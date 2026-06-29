import 'dart:math';
import 'package:flutter/material.dart';

/// Fondo decorativo light con formas suaves de colores STEAM.
class BackgroundShapes extends StatelessWidget {
  final bool darkMode;
  final int particleCount;

  const BackgroundShapes({
    super.key,
    this.darkMode = false,
    this.particleCount = 20,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return IgnorePointer(
      child: Stack(
        children: [
          // Círculos decorativos suaves
          Positioned(
            top: -40,
            right: -30,
            child: _Blob(diameter: 140, color: const Color(0xFF2D7FF9).withValues(alpha: 0.05)),
          ),
          Positioned(
            top: size.height * 0.3,
            left: -50,
            child: _Blob(diameter: 160, color: const Color(0xFF7C3AED).withValues(alpha: 0.04)),
          ),
          Positioned(
            bottom: size.height * 0.15,
            right: -40,
            child: _Blob(diameter: 120, color: const Color(0xFF10B981).withValues(alpha: 0.04)),
          ),
          Positioned(
            bottom: -30,
            left: size.width * 0.3,
            child: _Blob(diameter: 100, color: const Color(0xFFFF8C42).withValues(alpha: 0.04)),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double diameter;
  final Color color;
  const _Blob({required this.diameter, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

/// Fondo gradiente NIC (SOLO para splash y welcome)
class NicGradientBackground extends StatelessWidget {
  final Widget child;
  const NicGradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1E6FD9),
                Color(0xFF3A3CC7),
                Color(0xFF4E2DB5),
                Color(0xFF5E2695),
                Color(0xFF65227B),
                Color(0xFF6B1F65),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
            ),
          ),
        ),
        _Particles(count: 18),
        child,
      ],
    );
  }
}

class _Particles extends StatefulWidget {
  final int count;
  const _Particles({required this.count});

  @override
  State<_Particles> createState() => _ParticlesState();
}

class _ParticlesState extends State<_Particles> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _PPainter(progress: _ctrl.value, count: widget.count),
      ),
    );
  }
}

class _PPainter extends CustomPainter {
  final double progress;
  final int count;
  _PPainter({required this.progress, required this.count});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    for (int i = 0; i < count; i++) {
      final bx = rng.nextDouble() * size.width;
      final sp = 0.3 + rng.nextDouble() * 0.7;
      final r = 1.2 + rng.nextDouble() * 2.0;
      final a = 0.06 + rng.nextDouble() * 0.1;
      final angle = progress * 2 * pi * sp + i * 0.5;
      final d = 18.0 + rng.nextDouble() * 25.0;
      final x = bx + sin(angle) * d;
      final y = (rng.nextDouble() * size.height + progress * size.height * sp * 0.3) % size.height;
      canvas.drawCircle(Offset(x, y), r, Paint()
        ..color = Colors.white.withValues(alpha: a)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6));
    }
  }

  @override
  bool shouldRepaint(covariant _PPainter old) => old.progress != progress;
}
