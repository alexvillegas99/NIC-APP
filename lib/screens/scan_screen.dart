import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nic_pre_u/shared/widgets/background_shapes.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final String apiUrl = dotenv.env['API_URL'] ?? '';
  final MobileScannerController _controller = MobileScannerController();
  bool isProcessing = false;
  bool canScan = true;

  // ↓ Invisibles (no cambian UI)
  String? _lastValue;
  DateTime _lastScanAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _cooldown = Duration(seconds: 3);

  @override
  void dispose() {
    _controller.dispose(); // liberar cámara correctamente
    super.dispose();
  }

void _showAttendanceSnackbar(Map<String, dynamic> asistencia) {
  if (!mounted) return;

  final nombre = asistencia['nombre'] ?? '';
  final curso = asistencia['cursoNombre'] ?? '';
  final porcentaje = asistencia['porcentaje'] ?? 0;
  final estado = asistencia['estado'] ?? false; // true o false

  // color dinámico según estado
  final Color bgColor = estado ? Colors.green : Colors.redAccent;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
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
                          ? "Asistencia registrada"
                          : "Asistencia no válida",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text("👤 $nombre", style: const TextStyle(color: Colors.white)),
                    Text("📘 Curso: $curso", style: const TextStyle(color: Colors.white)),
                    Text("📊 Asistencia: $porcentaje%", style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 7),
      ),
    );
}


  Future<void> _sendAttendance(String qrData) async {
    if (!canScan || isProcessing) return;

    // Evita repetir el MISMO código dentro del cooldown (invisible al usuario)
    final now = DateTime.now();
    if (_lastValue == qrData && now.difference(_lastScanAt) < _cooldown) return;
    _lastValue = qrData;
    _lastScanAt = now;

    setState(() {
      isProcessing = true;
      canScan = false;
    });

    // Pausa cámara durante el proceso para que no “dispare” más lecturas
    await _controller.stop();

    try {
      if (apiUrl.isEmpty) {
        throw Exception('API_URL no configurada');
      }

      final qrParts = qrData.split(',');
      if (qrParts.length < 3) {
        throw Exception('Formato de código QR inválido');
      }

      final Uri endpoint = Uri.parse(
        apiUrl.endsWith('/')
            ? '${apiUrl}asistencias/registrar'
            : '$apiUrl/asistencias/registrar',
      );

      final response = await http
          .post(endpoint, body: {'cursoId': qrParts[2], 'cedula': qrParts[0]})
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      print('responseeeee ${response.body}');
      if (response.statusCode == 201) {
        ///imprimir resultado
        ///
        final data =  jsonDecode(response.body);
        final bool isValid = data['asistencia']['estado'];
        print('dataaaaa ${data['asistencia']}');
     _showAttendanceSnackbar(data['asistencia']);
        /*   _showSnackbar(
            '✅ Asistencia registrada para ${data['asistencia']['nombre']} perteneciente al curso ${data['asistencia']['cursoNombre']} porcentaje asistencia ${data['asistencia']['porcentaje']}',
            isValid ? Colors.green : Colors.orange,
          ); */
    
      } else {
        final msg = _getErrorMessage(response.statusCode);
        _showSnackbar('⚠️ $msg', Colors.red);
      }
    } on TimeoutException {
      _showSnackbar(
        '⏱️ Tiempo de espera agotado. Verifica tu conexión.',
        Colors.orange,
      );
    } catch (e) {
      _showSnackbar('❌ Error: ${e.toString()}', Colors.orange);
    } finally {
      if (!mounted) return;
      setState(() => isProcessing = false);

      // Pequeño cooldown para permitir el siguiente escaneo sin cambios visibles
      await Future.delayed(_cooldown);
      if (!mounted) return;

      setState(() => canScan = true);
      // Reanuda la cámara para el próximo escaneo
      unawaited(_controller.start());
    }
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
  }

  String _getErrorMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'El curso no está activo.';
      case 404:
        return 'El asistente no pertenece al curso.';
      case 409:
        return 'El asistente ya tiene asistencia registrada.';
      case 403:
        return 'Usuario inactivo. Contacta al administrador.';
      default:
        return 'Ocurrió un error inesperado.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Asegura que la cámara se detenga al salir (sin cambiar la UI)
      onWillPop: () async {
        await _controller.stop();
        return true;
      },
      child: Scaffold(
        body: Stack(
          children: [
            const BackgroundShapes(),

            // Cámara
            MobileScanner(
              controller: _controller,
              fit: BoxFit.cover,
              onDetect: (capture) {
                if (!canScan) return;
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final val = barcodes.first.rawValue ?? '';
                  if (val.isNotEmpty) {
                    _sendAttendance(val);
                  }
                }
              },
              // Manejo “silencioso” de errores de cámara
              errorBuilder: (context, error, child) {
                // No cambiamos la UI; solo avisamos por snackbar una vez
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _showSnackbar(
                      '📷 Permiso de cámara denegado o no disponible.',
                      Colors.orange,
                    );
                  }
                });
                return const SizedBox.shrink();
              },
            ),

            // UI sobre cámara (sin cambios visuales)
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  const Spacer(),
                  _buildScanFrame(),
                  const Spacer(),
                ],
              ),
            ),

            if (isProcessing)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- UI idéntica: no hay cambios visuales ---
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
            onPressed: () => Navigator.pop(context),
          ),
          Column(
            children: [
              Image.asset('assets/imagenes/logo.png', height: 80),
              const SizedBox(height: 5),
              const Text(
                'Escanea un código QR',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
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
}
