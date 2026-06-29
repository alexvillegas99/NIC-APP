import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:nic_pre_u/services/asistencia_service.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';

/// Escáner de asistencia por QR.
///
/// El profesor/asesor escanea el QR del estudiante (contiene su cédula) y la app
/// registra la asistencia SIN pedir el paralelo: resuelve la matrícula del
/// estudiante (`/asistentes/buscar/por-cedula`) y deja que el backend deduzca el
/// curso desde `asistente.courseId`. Si el estudiante tiene varios cursos activos
/// a la vez, muestra un mini-selector solo en ese caso.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final AsistenciaService _asistencia = AsistenciaService();

  bool isProcessing = false;
  bool canScan = true;

  // anti duplicados
  String? _lastValue;
  DateTime _lastScanAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _cooldown = Duration(seconds: 3);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Extrae la cédula del contenido del QR ───────────────────────────────────
  String _extraerCedula(String qrData) {
    final raw = qrData.trim();
    // El QR puede ser "cedula,nombre,..." o solo la cédula.
    final first = raw.split(',').first.trim();
    return first;
  }

  String _nombreDe(Map<String, dynamic> a) {
    final candidates = [
      a['nombre'],
      a['nombres'],
      a['fullName'],
      a['estudiante'],
      (a['user'] is Map) ? (a['user'] as Map)['nombre'] : null,
      (a['user'] is Map) ? (a['user'] as Map)['fullName'] : null,
    ];
    for (final c in candidates) {
      final s = (c ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  String _cursoDe(Map<String, dynamic> a) {
    if (a['curso'] is String && (a['curso'] as String).trim().isNotEmpty) {
      return (a['curso'] as String).trim();
    }
    final candidates = [
      a['cursoNombre'],
      (a['curso'] is Map) ? (a['curso'] as Map)['nombre'] : null,
      (a['course'] is Map) ? (a['course'] as Map)['nombre'] : null,
      (a['course'] is Map) ? (a['course'] as Map)['name'] : null,
    ];
    for (final c in candidates) {
      final s = (c ?? '').toString().trim();
      if (s.isNotEmpty) return _formatNombre(s);
    }
    return '';
  }

  dynamic _courseIdDe(Map<String, dynamic> a) =>
      a['courseId'] ?? a['course_id'] ?? a['cursoId'];

  bool _esActivo(Map<String, dynamic> a) {
    final estado = (a['estado'] ?? 'activo').toString().toLowerCase().trim();
    return estado == 'activo' || estado == 'active' || estado.isEmpty;
  }

  String _formatNombre(String text) => text
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .split(' ')
      .map((w) => w.isEmpty
          ? w
          : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');

  // ── Flujo principal ──────────────────────────────────────────────────────────
  Future<void> _onScan(String qrData) async {
    if (!canScan || isProcessing) return;

    final now = DateTime.now();
    if (_lastValue == qrData && now.difference(_lastScanAt) < _cooldown) return;
    _lastValue = qrData;
    _lastScanAt = now;

    final cedula = _extraerCedula(qrData);
    if (cedula.isEmpty) {
      _showSnackbar('QR inválido', DS.warning);
      return;
    }

    setState(() {
      isProcessing = true;
      canScan = false;
    });
    HapticFeedback.mediumImpact();
    await _controller.stop();

    try {
      final asistentes = await _asistencia.asistentesPorCedula(cedula);

      if (asistentes.isEmpty) {
        _showSnackbar('Estudiante no encontrado ($cedula)', DS.error);
        return;
      }

      // Candidatos activos con curso asignado.
      final candidatos = asistentes
          .where((a) => _esActivo(a) && _courseIdDe(a) != null)
          .toList();

      // Si ninguno tiene curso, intenta con el primero (el back puede deducirlo).
      Map<String, dynamic> elegido;
      if (candidatos.isEmpty) {
        elegido = asistentes.first;
      } else if (candidatos.length == 1) {
        elegido = candidatos.first;
      } else {
        // Varios cursos activos → mini-selector.
        final pick = await _elegirCurso(candidatos);
        if (pick == null) {
          return; // cancelado
        }
        elegido = pick;
      }

      await _registrar(elegido);
    } catch (e) {
      _showSnackbar('Error: $e', DS.warning);
    } finally {
      if (mounted) {
        setState(() => isProcessing = false);
        await Future.delayed(_cooldown);
        if (mounted) {
          setState(() => canScan = true);
          unawaited(_controller.start());
        }
      }
    }
  }

  Future<void> _registrar(Map<String, dynamic> asistente) async {
    final res = await _asistencia.registrar(
      asistenteId: asistente['id'],
      courseId: _courseIdDe(asistente),
    );
    if (!mounted) return;
    if (res.ok) {
      _showResultadoOk(
        nombre: _nombreDe(asistente),
        curso: _cursoDe(asistente),
        deduped: res.deduped,
      );
    } else {
      _showSnackbar(res.mensaje ?? 'No se pudo registrar', DS.error);
    }
  }

  // ── Mini-selector de curso (solo si hay varios activos) ──────────────────────
  Future<Map<String, dynamic>?> _elegirCurso(
      List<Map<String, dynamic>> cursos) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: DS.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: DS.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text('¿En qué curso registrar?',
                  style: DS.poppins(
                      size: 17,
                      weight: FontWeight.w700,
                      color: DS.textPrimary)),
              const SizedBox(height: 4),
              Text('El estudiante tiene varios cursos activos',
                  style: DS.poppins(size: 12, color: DS.textSecondary)),
              const SizedBox(height: 14),
              ...cursos.map((c) {
                final nombre = _cursoDe(c).isEmpty ? 'Curso' : _cursoDe(c);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: DS.cardSoft,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(context, c),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Icon(Icons.menu_book_rounded,
                                color: DS.purple, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(nombre,
                                  style: DS.poppins(
                                      size: 14,
                                      weight: FontWeight.w600,
                                      color: DS.textPrimary)),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded,
                                size: 14, color: DS.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            fit: BoxFit.cover,
            onDetect: (capture) {
              if (!canScan) return;
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final val = barcodes.first.rawValue ?? '';
                if (val.isNotEmpty) _onScan(val);
              }
            },
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => Navigator.maybePop(context),
                      borderRadius: BorderRadius.circular(12),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Registrar asistencia',
                            style: DS.poppins(
                                size: 16,
                                weight: FontWeight.w700,
                                color: Colors.white)),
                        Text('Escanea el QR del estudiante',
                            style: DS.poppins(
                                size: 12,
                                color: Colors.white.withValues(alpha: 0.7))),
                      ],
                    ),
                  ),
                  // Flash toggle
                  Material(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _controller.toggleTorch();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(Icons.flash_on_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scan frame
          Center(child: _buildScanFrame()),

          // Bottom hint
          Positioned(
            bottom: 70,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Coloca el QR dentro del marco',
                    style: DS.poppins(
                        size: 13,
                        weight: FontWeight.w500,
                        color: Colors.white)),
              ),
            ),
          ),

          // Processing overlay
          if (isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text('Registrando asistencia...',
                        style: DS.poppins(
                            size: 15,
                            weight: FontWeight.w500,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScanFrame() {
    const double size = 250;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ScanFramePainter(
          cornerLength: 30,
          strokeWidth: 4,
          gradientColors: DS.gradientColors.take(3).toList(),
        ),
      ),
    );
  }

  // ── Feedback ───────────────────────────────────────────────────────────────
  void _showSnackbar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, style: DS.poppins(size: 14, color: Colors.white)),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  void _showResultadoOk({
    required String nombre,
    required String curso,
    required bool deduped,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DS.success,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: DS.success.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        deduped
                            ? 'Asistencia ya estaba registrada'
                            : 'Asistencia registrada',
                        style: DS.poppins(
                            size: 15,
                            weight: FontWeight.w700,
                            color: Colors.white),
                      ),
                      if (nombre.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(nombre,
                            style:
                                DS.poppins(size: 13, color: Colors.white)),
                      ],
                      if (curso.isNotEmpty)
                        Text(curso,
                            style: DS.poppins(
                                size: 13,
                                color: Colors.white.withValues(alpha: 0.85))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scan Frame Painter (esquinas redondeadas con gradiente)
// ─────────────────────────────────────────────────────────────────────────────
class _ScanFramePainter extends CustomPainter {
  final double cornerLength;
  final double strokeWidth;
  final List<Color> gradientColors;

  _ScanFramePainter({
    required this.cornerLength,
    required this.strokeWidth,
    required this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: gradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const radius = 16.0;

    final tlPath = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(cornerLength, 0);
    canvas.drawPath(tlPath, paint);

    final trPath = Path()
      ..moveTo(size.width - cornerLength, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, cornerLength);
    canvas.drawPath(trPath, paint);

    final blPath = Path()
      ..moveTo(0, size.height - cornerLength)
      ..lineTo(0, size.height - radius)
      ..quadraticBezierTo(0, size.height, radius, size.height)
      ..lineTo(cornerLength, size.height);
    canvas.drawPath(blPath, paint);

    final brPath = Path()
      ..moveTo(size.width - cornerLength, size.height)
      ..lineTo(size.width - radius, size.height)
      ..quadraticBezierTo(
          size.width, size.height, size.width, size.height - radius)
      ..lineTo(size.width, size.height - cornerLength);
    canvas.drawPath(brPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
