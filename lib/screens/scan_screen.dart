import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:nic_pre_u/services/course_service.dart';
import 'package:nic_pre_u/shared/widgets/background_shapes.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final CourseService _courseService = CourseService();
  final TextEditingController _searchCtrl = TextEditingController();

  final String apiUrl = dotenv.env['API_URL'] ?? '';

  // modo
  bool selectingCourse = true;

  // cursos
  bool loadingCursos = true;
  List<Map<String, dynamic>> cursos = [];
  List<Map<String, dynamic>> cursosFiltrados = [];
  Map<String, dynamic>? cursoSeleccionado;

  // escaneo
  bool isProcessing = false;
  bool canScan = false;

  // anti duplicados
  String? _lastValue;
  DateTime _lastScanAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _cooldown = Duration(seconds: 3);

  static const Color kBaseBg = Color(0xFF0F1220);
  static const Color kCardBg = Color(0xFF111320);

  @override
  void initState() {
    super.initState();
    _loadCursos();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }


String formatNombre(String text) {
  return text
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) =>
          w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');
}

  /* ============================================================
   *  CARGAR CURSOS
   * ============================================================ */
Future<void> _loadCursos() async {
  try {
    final list = await _courseService.getActiveCourses();

    final mapped = list.map<Map<String, dynamic>>((c) {
      return {
        ...c,
        'nombre': formatNombre(c['nombre'] ?? ''),
      };
    }).toList();

    setState(() {
      cursos = mapped;
      cursosFiltrados = mapped;
      loadingCursos = false;
    });
  } catch (_) {
    loadingCursos = false;
    _showSnackbar('❌ Error cargando cursos activos', Colors.red);
  }
}


  void _filtrarCursos(String q) {
    setState(() {
      cursosFiltrados = cursos
          .where(
            (c) => c['nombre']
                .toString()
                .toLowerCase()
                .contains(q.toLowerCase()),
          )
          .toList();
    });
  }

  void _selectCurso(Map<String, dynamic> curso) {
    setState(() {
      cursoSeleccionado = curso;
      selectingCourse = false;
      canScan = true;
    });
  }

  /* ============================================================
   *  ESCANEAR
   * ============================================================ */
  Future<void> _sendAttendance(String qrData) async {
    if (!canScan || isProcessing || cursoSeleccionado == null) return;

    final now = DateTime.now();
    if (_lastValue == qrData && now.difference(_lastScanAt) < _cooldown) return;

    _lastValue = qrData;
    _lastScanAt = now;

    setState(() {
      isProcessing = true;
      canScan = false;
    });

    await _controller.stop();

    try {
      final parts = qrData.split(',');
      if (parts.isEmpty) throw Exception('QR inválido');

      final uri = Uri.parse(
        apiUrl.endsWith('/')
            ? '${apiUrl}asistencias/registrar'
            : '$apiUrl/asistencias/registrar',
      );

      final res = await http.post(
        uri,
        body: {
          'cursoId': cursoSeleccionado!['_id'],
          'cedula': parts[0],
        },
      );

      if (!mounted) return;

      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        _showAttendanceSnackbar(data['asistencia']);
      } else {
        _showSnackbar(
          '⚠️ ${_getErrorMessage(res.statusCode)}',
          Colors.red,
        );
      }
    } catch (e) {
      _showSnackbar('❌ ${e.toString()}', Colors.orange);
    } finally {
      if (!mounted) return;
      setState(() => isProcessing = false);
      await Future.delayed(_cooldown);
      setState(() => canScan = true);
      unawaited(_controller.start());
    }
  }

  /* ============================================================
   *  UI
   * ============================================================ */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🔥 FONDO OSCURO BASE (OBLIGATORIO)
          Container(color: kBaseBg),

          // 🔥 SHAPES ENCIMA DEL FONDO OSCURO
          const BackgroundShapes(),

          selectingCourse ? _buildCourseSelector() : _buildScanner(),

          if (isProcessing)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  /* =======================
   *  VISTA 1: CURSOS
   * ======================= */
  Widget _buildCourseSelector() {
    return SafeArea(
      child: Column(
        children: [
          _buildTopBar('Selecciona un curso', showLogo: true),

          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _filtrarCursos,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar curso...',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                filled: true,
                fillColor: kCardBg,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
            ),
          ),

          Expanded(
            child: loadingCursos
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : ListView.builder(
                    itemCount: cursosFiltrados.length,
                    itemBuilder: (_, i) {
                      final c = cursosFiltrados[i];
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: kCardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          title: Text(
                            c['nombre'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.qr_code,
                            color: Colors.white,
                          ),
                          onTap: () => _selectCurso(c),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /* =======================
   *  VISTA 2: ESCÁNER
   * ======================= */
  Widget _buildScanner() {
    return WillPopScope(
      onWillPop: () async {
        setState(() {
          selectingCourse = true;
          cursoSeleccionado = null;
          canScan = false;
        });
        await _controller.stop();
        return false;
      },
      child: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            fit: BoxFit.cover,
            onDetect: (capture) {
              if (!canScan) return;
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final val = barcodes.first.rawValue ?? '';
                if (val.isNotEmpty) {
                  _sendAttendance(val);
                }
              }
            },
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(
                  cursoSeleccionado!['nombre'],
                  showLogo: true,
                ),
                const Spacer(),
                _buildScanFrame(),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(String title, {bool showLogo = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back,
                color: Colors.white, size: 28),
            onPressed: () {
              if (selectingCourse) {
                Navigator.pop(context);
              } else {
                setState(() {
                  selectingCourse = true;
                  cursoSeleccionado = null;
                  canScan = false;
                });
                _controller.stop();
              }
            },
          ),
          Expanded(
            child: Column(
              children: [
                if (showLogo)
                  Image.asset(
                    'assets/imagenes/logo.png',
                    height: 60,
                  ),
                const SizedBox(height: 4),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildScanFrame() {
    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 4),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  /* ============================================================
   *  FEEDBACK
   * ============================================================ */
  void _showSnackbar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.white)),
          backgroundColor: color,
        ),
      );
  }

  void _showAttendanceSnackbar(Map<String, dynamic> a) {
    final bool estado = a['estado'] == true;
    final String nombre = a['nombre'] ?? '';
    final String curso = a['cursoNombre'] ?? '';
    final int porcentaje = a['porcentaje'] ?? 0;

    final Color bg = estado ? Colors.green : Colors.red;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 7),
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  estado ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        estado
                            ? 'Asistencia registrada'
                            : 'Asistencia no válida',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('👤 $nombre',
                          style: const TextStyle(color: Colors.white)),
                      Text('📘 Curso: $curso',
                          style: const TextStyle(color: Colors.white)),
                      Text('📊 Asistencia: $porcentaje%',
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  String _getErrorMessage(int code) {
    switch (code) {
      case 400:
        return 'Curso no activo';
      case 404:
        return 'Asistente no pertenece al curso';
      case 409:
        return 'Asistencia ya registrada';
      default:
        return 'Error inesperado';
    }
  }
}
