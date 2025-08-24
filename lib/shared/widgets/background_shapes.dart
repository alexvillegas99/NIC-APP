import 'package:flutter/material.dart';

class BackgroundShapes extends StatelessWidget {
  const BackgroundShapes({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 🔹 Círculos
        Positioned(top: -50, left: -50, child: _buildCircle(120, Colors.deepPurple.withOpacity(0.2))),
        Positioned(bottom: -80, right: -80, child: _buildCircle(180, Colors.deepPurple.withOpacity(0.1))),

        // 🔹 Triángulos
        Positioned(top: 100, left: 50, child: _buildTriangle(80, Colors.deepPurple.withOpacity(0.3))),
        Positioned(bottom: 200, right: 50, child: _buildTriangle(100, Colors.deepPurple.withOpacity(0.15))),

        // 🔹 Rectángulos rotados
        Positioned(top: 250, left: -80, child: _buildRectangle(120, 60, Colors.deepPurple.withOpacity(0.1), angle: -20)),
        Positioned(bottom: 100, right: -60, child: _buildRectangle(100, 50, Colors.deepPurple.withOpacity(0.2), angle: 15)),
      ],
    );
  }

  // 🔹 Función para generar círculos
  Widget _buildCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  // 🔹 Función para generar triángulos
  Widget _buildTriangle(double size, Color color) {
    return CustomPaint(
      size: Size(size, size),
      painter: _TrianglePainter(color),
    );
  }

  // 🔹 Función para generar rectángulos rotados
  Widget _buildRectangle(double width, double height, Color color, {double angle = 0}) {
    return Transform.rotate(
      angle: angle * (3.1416 / 180), // Convertir grados a radianes
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

// 🎨 Clase para dibujar un triángulo
class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final Path path = Path()
      ..moveTo(size.width / 2, 0) // Punto superior
      ..lineTo(size.width, size.height) // Esquina inferior derecha
      ..lineTo(0, size.height) // Esquina inferior izquierda
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
