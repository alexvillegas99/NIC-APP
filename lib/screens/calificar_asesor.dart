import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nic_pre_u/services/rating_service.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';
import 'package:nic_pre_u/shared/widgets/nic_header.dart';
import 'package:nic_pre_u/shared/widgets/glass_card.dart';
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
    {
      'value': 4,
      'label': 'Satisfecho',
      'asset': 'assets/imagenes/Asset 3.png',
    },
    {
      'value': 3,
      'label': 'Neutral',
      'asset': 'assets/imagenes/Asset 4.png',
    },
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
      body: Stack(
        children: [
          const BackgroundShapes(),
          Column(
            children: [
              NicHeader(
                title: 'Calificar atención',
                color: DS.green,
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header info card
                      NicCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: DS.nicGradient,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.support_agent_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Calificacion de atencion',
                                        style: DS.poppins(
                                          size: 17,
                                          weight: FontWeight.w700,
                                          color: DS.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Evalue la atencion recibida por el asesor',
                                        style: DS.poppins(
                                          size: 13,
                                          weight: FontWeight.w400,
                                          color: DS.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Question
                      Text(
                        'Como calificas la atencion recibida?',
                        textAlign: TextAlign.center,
                        style: DS.poppins(
                          size: 16,
                          weight: FontWeight.w600,
                          color: DS.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Rating options
                      ..._opciones.map((opt) {
                        final selected = calificacion == opt['value'];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => setState(
                                  () => calificacion = opt['value'] as int),
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: selected
                                        ? DS.primary
                                        : DS.divider,
                                    width: selected ? 2 : 1,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: DS.primary
                                                .withValues(alpha: 0.15),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.04),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: DS.bg,
                                      foregroundImage: AssetImage(
                                        opt['asset'] as String,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Text(
                                      opt['label'] as String,
                                      style: DS.poppins(
                                        size: 15,
                                        weight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: DS.textPrimary,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (selected)
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          gradient: DS.nicGradient,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 20),

                      // Observation field
                      TextField(
                        controller: _obsCtrl,
                        maxLines: 3,
                        style: DS.poppins(
                          size: 14,
                          color: DS.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Observacion (opcional)',
                          hintStyle: DS.poppins(
                            size: 14,
                            color: DS.textSecondary.withValues(alpha: 0.5),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                BorderSide(color: DS.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                BorderSide(color: DS.divider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: DS.primary, width: 1.5),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Submit button
                      AnimatedOpacity(
                        opacity: calificacion != null ? 1.0 : 0.5,
                        duration: const Duration(milliseconds: 200),
                        child: NicGradientButton(
                          text: 'Enviar calificacion',
                          icon: Icons.send_rounded,
                          onPressed: calificacion == null
                              ? () {}
                              : () => _confirmarEnvio(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Confirm Dialog ─────────────────────────────────────────────────────────

  void _confirmarEnvio(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: DS.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: DS.nicGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Confirmar envio',
                style: DS.poppins(
                  size: 18,
                  weight: FontWeight.w700,
                  color: DS.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Desea enviar la calificacion?',
                style: DS.poppins(
                  size: 14,
                  color: DS.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: NicOutlineButton(
                      text: 'Cancelar',
                      height: 48,
                      onPressed: _enviando
                          ? () {}
                          : () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NicGradientButton(
                      text: 'Confirmar',
                      height: 48,
                      onPressed: _enviando
                          ? () {}
                          : () async {
                              Navigator.pop(context);
                              await _enviarYVolverHome(context);
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gracias por tu calificacion',
              style: DS.poppins(size: 14, color: Colors.white),
            ),
            backgroundColor: DS.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      debugPrint('Error envio: $e');
      if (!mounted) return;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo enviar la calificacion',
              style: DS.poppins(size: 14, color: Colors.white),
            ),
            backgroundColor: DS.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }
}
