// lib/shared/widgets/next_class_card.dart
import 'package:flutter/material.dart';
import '../ui/design_system.dart';

class NextClassCard extends StatelessWidget {
  final String titulo;
  final String modalidad;
  final String hora;
  final Duration en; // tiempo restante

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
        decoration: DS.cardDeco(glow: true),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Clase: $titulo', style: DS.h2),
                  const SizedBox(height: 6),
                  Text('Modalidad: $modalidad', style: DS.pDim),
                  Text('Hora: $hora', style: DS.pDim),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DS.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: () {},
                    icon: const Icon(Icons.play_circle),
                    label: const Text('Ingresar a clase'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _CountdownRing(text: 'En ${minutes}min'),
          ],
        ),
      ),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  final String text;
  const _CountdownRing({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76, height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [DS.primary, DS.accent, DS.primary],
        ),
      ),
      child: Center(
        child: Container(
          width: 66, height: 66,
          decoration: const BoxDecoration(
            shape: BoxShape.circle, color: DS.card,
          ),
          alignment: Alignment.center,
          child: Text(text, textAlign: TextAlign.center, style: DS.p),
        ),
      ),
    );
  }
}
