import 'package:flutter/material.dart';
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
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '¿Cómo califica la atención recibida?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),

          // ===== BOTONES =====
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final value = index + 1;
              final selected = calificacion == value;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: InkWell(
                  onTap: () => setState(() => calificacion = value),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFF1F2937),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF7C3AED)
                            : Colors.white24,
                      ),
                    ),
                    child: Text(
                      value.toString(),
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 8),

          // ===== BAJA / ALTA =====
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Baja', style: TextStyle(color: Colors.white60, fontSize: 12)),
              Text('Alta', style: TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),

          const SizedBox(height: 24),

          // ===== OBSERVACIÓN (OPCIONAL) =====
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

          const SizedBox(height: 28),

          // ===== BOTÓN ENVIAR =====
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
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
  final usuario =
      _user?['email'] ?? _user?['nombre'] ?? 'desconocido';

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
      const SnackBar(
        content: Text('Gracias por tu calificación'),
      ),
    );

    // 🔴 ENVÍA AL HOME (borra stack)
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se pudo enviar la calificación'),
      ),
    );
  } finally {
    if (mounted) setState(() => _enviando = false);
  }
}

}
