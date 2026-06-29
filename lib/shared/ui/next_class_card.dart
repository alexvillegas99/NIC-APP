import 'package:flutter/material.dart';
import '../ui/design_system.dart';

class NextClassCard extends StatelessWidget {
  final String titulo;
  final String modalidad;
  final String hora;
  final Duration en;

  const NextClassCard({
    super.key,
    required this.titulo,
    required this.modalidad,
    required this.hora,
    required this.en,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = en.inMinutes.clamp(0, 999);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: DS.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: DS.divider),
          boxShadow: [
            BoxShadow(
              color: DS.purple.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clase: $titulo',
                    style: DS.poppins(
                      size: 16,
                      weight: FontWeight.w700,
                      color: DS.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Modalidad: $modalidad',
                    style: DS.poppins(size: 13, color: DS.textSecondary),
                  ),
                  Text(
                    'Hora: $hora',
                    style: DS.poppins(size: 13, color: DS.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: DS.purple,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_circle_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Ingresar a clase',
                          style: DS.poppins(
                            size: 13,
                            weight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _CountdownRing(minutes: minutes),
          ],
        ),
      ),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  final int minutes;
  const _CountdownRing({required this.minutes});

  @override
  Widget build(BuildContext context) {
    final label = minutes == 0 ? 'Ahora' : 'En ${minutes}min';
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 76,
          height: 76,
          child: CircularProgressIndicator(
            value: (minutes / 60).clamp(0.0, 1.0),
            strokeWidth: 5,
            backgroundColor: DS.cardSoft,
            valueColor: const AlwaysStoppedAnimation<Color>(DS.purple),
            strokeCap: StrokeCap.round,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: DS.poppins(
            size: 11,
            weight: FontWeight.w700,
            color: DS.textPrimary,
          ),
        ),
      ],
    );
  }
}
