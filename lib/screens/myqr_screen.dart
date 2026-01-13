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

  // Estados
  String? _qrData;
  String _nombre = '';
  String _cedula = '';
  bool _loading = true;
  String? _error;

  // Paleta
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
      final res = await _auth.getUser();
      if (res == null) {
        throw Exception('Usuario nulo');
      }

      final user = res['user'] ?? res;

      _cedula = user['cedula']?.toString() ?? '';
      _nombre = user['nombre']?.toString() ?? '';

      _generarQR(user);

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = 'Error al generar el QR';
        _loading = false;
      });
    }
  }

  void _generarQR(Map<String, dynamic> user) {
    final createdAtEcuador =
        user['createdAtEcuador'] ?? _toEcuadorString(user['createdAt']);
    _qrData = '$_cedula,$_nombre,$createdAtEcuador';
  }

  String _toEcuadorString(dynamic createdAt) {
    DateTime base = createdAt != null
        ? (DateTime.tryParse(createdAt.toString()) ?? DateTime.now())
        : DateTime.now();
    final ec = base.toUtc().subtract(const Duration(hours: 5));
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(ec);
  }

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
    final qrSize = (w * 0.64).clamp(220, 320).toDouble();

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kText),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'NIC',
          style: TextStyle(color: kPurple, fontWeight: FontWeight.w800),
        ),
      ),
   body: SafeArea(
  child: Center( // <- Asegura centrado horizontal
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Tu código QR',
            style: TextStyle(
              color: kPurple,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // QR centrado
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kPurple, width: 6),
            ),
            child: _loading
                ? SizedBox(
                    height: qrSize,
                    width: qrSize,
                    child: const Center(child: CircularProgressIndicator()),
                  )
                : QrImageView(
                    data: _qrData ?? '',
                    size: qrSize,
                    backgroundColor: Colors.white,
                  ),
          ),

          const SizedBox(height: 20),

          Text(
            _nombre,
            style: const TextStyle(
              color: kText,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
            textAlign: TextAlign.center, // <- Centra texto
          ),
          const SizedBox(height: 6),
          Text(
            'Código: $_prettyCode',
            style: const TextStyle(color: kSub),
            textAlign: TextAlign.center, // <- Centra texto
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center, // <- Centra texto
            ),
          ],
        ],
      ),
    ),
  ),
),
 );
  }
}
