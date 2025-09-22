import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:nic_pre_u/services/auth_service.dart';

class MyQRScreen extends StatefulWidget {
  const MyQRScreen({super.key});
  @override
  State<MyQRScreen> createState() => _MyQRScreenState();
}

class _MyQRScreenState extends State<MyQRScreen> {
  final _auth = AuthService();

  String? _qrData;          // "{cedula},{nombre},{curso},{createdAtEcuador}"
  String _nombre = 'Estudiante';
  String _cedula = '';
  bool _loading = true;
  String? _error;

  // Paleta del mock
  static const kBg = Color(0xFF0F1220);
  static const kPurple = Color(0xFF8A5CF6);
  static const kText = Color(0xFFE8EAF6);
  static const kSub = Color(0xFF9AA3B2);

  @override
  void initState() {
    super.initState();
    _loadQRData();
  }

  Future<void> _loadQRData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await _auth.getUser(); // Map<String, dynamic>?
      if (user == null) {
        setState(() {
          _error = 'No se pudo obtener el usuario.';
          _loading = false;
        });
        return;
      }

      _cedula = (user['cedula'] ?? user['dni'] ?? '').toString().trim();
      _nombre = (user['nombre'] ?? user['name'] ?? 'Estudiante').toString().trim();
      final curso = (user['curso'] ?? user['grado'] ?? '').toString().trim();

      final createdAtEcuador = (user['createdAtEcuador']?.toString().isNotEmpty ?? false)
          ? user['createdAtEcuador'].toString()
          : _toEcuadorString(user['createdAt']);

      final data = '$_cedula,$_nombre,$curso,$createdAtEcuador';

      if (!mounted) return;
      setState(() {
        _qrData = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo preparar el código QR.';
        _loading = false;
      });
    }
  }

  String _toEcuadorString(dynamic createdAt) {
    DateTime base = createdAt != null
        ? (DateTime.tryParse(createdAt.toString()) ?? DateTime.now())
        : DateTime.now();
    final ec = base.toUtc().subtract(const Duration(hours: 5));
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(ec);
  }

  // “Código: 12-14-15-16” desde la cédula
  String get _prettyCode {
    final s = _cedula.replaceAll(RegExp(r'\D'), '');
    if (s.isEmpty) return '--';
    final chunks = <String>[];
    for (var i = 0; i < s.length; i += 2) {
      chunks.add(s.substring(i, (i + 2).clamp(0, s.length)));
    }
    return chunks.join('-');
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final qrSize = (w * 0.64).clamp(220, 320); // tamaño aproximado del mock

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: const [
            /* Text('', style: TextStyle(color: kText, fontWeight: FontWeight.w900)),
            SizedBox(width: 8), */
            Text('NIC',
                style: TextStyle(color: kPurple, fontWeight: FontWeight.w700)),
          ],
        ),
        centerTitle: false,
      ),
body: SafeArea(
  child: LayoutBuilder(
    builder: (context, constraints) {
      final w = MediaQuery.of(context).size.width;
      final qrSize = (w * 0.64).clamp(220, 320).toDouble();

      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              // 👇 Centrado vertical
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Título y subtítulo
                const Text(
                  'Tú código QR',
                  style: TextStyle(
                    color: Color(0xFF8A5CF6),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pídele al profesor que escanee tu QR para poder tomar la asistencia.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF9AA3B2), fontSize: 14),
                ),
                const SizedBox(height: 24),

                // Tarjeta del QR (centrado)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(color: Color(0xFF8A5CF6), width: 6),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 240, width: 240,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : (_error != null || _qrData == null)
                              ? SizedBox(
                                  height: 240, width: 240,
                                  child: Center(
                                    child: Text(
                                      _error ?? 'Sin datos',
                                      style: const TextStyle(color: Colors.redAccent),
                                    ),
                                  ),
                                )
                              : QrImageView(
                                  data: _qrData!,
                                  version: QrVersions.auto,
                                  size: qrSize,
                                  backgroundColor: Colors.white,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Colors.black,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: Colors.black,
                                  ),
                                ),
                    ),
                    Positioned(
                      right: -6,
                      bottom: -10,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFF8A5CF6),
                        child: Text(
                          (_nombre.isNotEmpty ? _nombre[0] : 'A').toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // Nombre y código
                Text(
                  _nombre.isEmpty ? 'Nombre Estudiante' : _nombre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFE8EAF6),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Código: ${_prettyCode}',
                  style: const TextStyle(color: Color(0xFF9AA3B2), fontSize: 14),
                ),

                const SizedBox(height: 28), // respiro inferior
              ],
            ),
          ),
        ),
      );
    },
  ),
),


   );
  }
}
