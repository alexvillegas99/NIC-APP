import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nic_pre_u/services/rating_service.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';
import 'package:nic_pre_u/shared/widgets/background_shapes.dart';
import 'package:nic_pre_u/services/auth_service.dart';

class CalificarAtencionScreen extends StatefulWidget {
  const CalificarAtencionScreen({super.key});

  @override
  State<CalificarAtencionScreen> createState() =>
      _CalificarAtencionScreenState();
}

class _CalificarAtencionScreenState extends State<CalificarAtencionScreen> {
  int? calificacion;
  final TextEditingController _obsCtrl = TextEditingController();
  final RatingService _ratingService = RatingService();
  bool _enviando = false;

  final AuthService _authService = AuthService();
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _authService.getUser();
    if (mounted) {
      setState(() => _user = user);
    }
  }

  final _opciones = [
    {
      'value': 5,
      'label': 'Muy satisfecho',
      'asset': 'assets/imagenes/Asset 2.png',
    },
    {'value': 4, 'label': 'Satisfecho', 'asset': 'assets/imagenes/Asset 3.png'},
    {'value': 3, 'label': 'Neutral', 'asset': 'assets/imagenes/Asset 4.png'},
    {
      'value': 2,
      'label': 'Insatisfecho',
      'asset': 'assets/imagenes/Asset 5.png',
    },
    {
      'value': 1,
      'label': 'Muy insatisfecho',
      'asset': 'assets/imagenes/Asset 6.png',
    },
  ];

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DS.bg,

      appBar: AppBar(
        backgroundColor: DS.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'NIC',
          style: TextStyle(
            color: Color(0xFF7C3AED),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      body: Stack(
        children: [
          const BackgroundShapes(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _headerCard(),
                  const SizedBox(height: 20),
                  _ratingCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= HEADER =================

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111320),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calificación de atención',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Evalúe la atención recibida por el asesor',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ================= CARD CALIFICACIÓN =================
  Widget _ratingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111320),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '¿Cómo calificas la atención recibida?',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== OPCIONES =====
              Expanded(
                child: Column(
                  children: _opciones.map((opt) {
                    final selected = calificacion == opt['value'];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () =>
                            setState(() => calificacion = opt['value'] as int),
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 14,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2937),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF7C3AED)
                                  : Colors.white24,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(
                                  0xFF1F2937,
                                ), // mismo fondo del card
                                foregroundImage: AssetImage(
                                  opt['asset'] as String,
                                ),
                              ),

                              const SizedBox(width: 12),
                              Text(
                                opt['label'] as String,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ===== OBSERVACIÓN =====
          TextField(
            controller: _obsCtrl,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Observación (opcional)',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1F2937),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ===== BOTÓN =====
          ElevatedButton(
            onPressed: calificacion == null
                ? null
                : () => _confirmarEnvio(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              disabledBackgroundColor: Colors.white12,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Enviar calificación',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= CONFIRMACIÓN =================

  void _confirmarEnvio(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111320),
        title: const Text(
          'Confirmar envío',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '¿Desea enviar la calificación?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: _enviando ? null : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: _enviando
                ? null
                : () async {
                    Navigator.pop(context);
                    await _enviarYVolverHome(context);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            child: const Text(
              'Confirmar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _enviarYVolverHome(BuildContext context) async {
    final usuario = _user?['email'] ?? _user?['nombre'] ?? 'desconocido';

    final observacion = _obsCtrl.text.trim();

    setState(() => _enviando = true);

    try {
      await _ratingService.enviarCalificacion(
        usuario: usuario,
        calificacion: calificacion!,
        observacion: observacion.isEmpty ? null : observacion,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gracias por tu calificación')),
      );

      // 🔴 ENVÍA AL HOME (borra stack)
     context.go('/home');

    } catch (e) {
  print('userrrrrr: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar la calificación')),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }
}
