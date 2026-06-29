import 'package:flutter/material.dart';
import 'package:nic_pre_u/screens/premium_screen.dart';
import 'package:nic_pre_u/services/last_activity_service.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';

/// Course detail bottom sheet — video + description + temario + premium CTA
class CourseDetailSheet extends StatefulWidget {
  final Map<String, dynamic> course;
  const CourseDetailSheet({super.key, required this.course});

  static void show(BuildContext context, Map<String, dynamic> course) {
    // Recuerda este curso como "última actividad" para el home.
    final nombre = (course['nombre'] ??
            course['fullname'] ??
            course['name'] ??
            'Curso')
        .toString()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
    LastActivityService().recordCurso(
      title: nombre,
      subtitle: 'Continúa tu curso',
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CourseDetailSheet(course: course),
    );
  }

  @override
  State<CourseDetailSheet> createState() => _CourseDetailSheetState();
}

class _CourseDetailSheetState extends State<CourseDetailSheet> {
  bool _temarioExpanded = false;

  String get _name =>
      (widget.course['nombre'] ??
              widget.course['fullname'] ??
              widget.course['name'] ??
              'Curso')
          .toString()
          .replaceAll('_', ' ')
          .replaceAll('-', ' ');

  String get _description =>
      (widget.course['descripcion'] ??
              widget.course['description'] ??
              widget.course['summary'] ??
              'Descubre todo lo que aprenderás en este curso. Contenido diseñado para llevarte del nivel básico al avanzado con ejercicios prácticos y evaluaciones.')
          .toString();

  String get _tutor =>
      (widget.course['tutor'] ??
              widget.course['teacher'] ??
              widget.course['docente'] ??
              'Docente NIC')
          .toString();

  String get _modality {
    final horario = widget.course['horario'] as List?;
    if (horario != null && horario.isNotEmpty) {
      return (horario.first['Modalidad'] ?? 'Presencial').toString();
    }
    return (widget.course['modalidad'] ??
            widget.course['modality'] ??
            'Presencial')
        .toString();
  }

  List<_TemarioItem> get _temario {
    final items = widget.course['temario'] as List?;
    if (items != null) {
      return items
          .asMap()
          .entries
          .map((e) => _TemarioItem(
                number: e.key + 1,
                title: e.value.toString(),
              ))
          .toList();
    }
    // Fallback generic temario
    return const [
      _TemarioItem(number: 1, title: 'Introducción y bases del curso'),
      _TemarioItem(number: 2, title: 'Fundamentos teóricos'),
      _TemarioItem(number: 3, title: 'Práctica y ejercicios guiados'),
      _TemarioItem(number: 4, title: 'Evaluación intermedia'),
      _TemarioItem(number: 5, title: 'Temas avanzados'),
      _TemarioItem(number: 6, title: 'Proyecto final y cierre'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141422),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: DS.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: EdgeInsets.zero,
                children: [
                  // ─ Video thumbnail ─
                  _buildVideoThumb(),

                  // ─ Course info ─
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Modality pill
                        Row(
                          children: [
                            _Pill(
                              label: _modality,
                              color: DS.purple,
                            ),
                            const SizedBox(width: 8),
                            _Pill(
                              label: 'NIC Academy',
                              color: DS.cyan,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Course name
                        Text(
                          _name,
                          style: DS.poppins(
                            size: 20,
                            weight: FontWeight.w800,
                            color: DS.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Tutor row
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: DS.purple.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_rounded,
                                  color: DS.purple, size: 16),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _tutor,
                              style: DS.poppins(
                                  size: 13, color: DS.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ─ Description ─
                        Text(
                          'Descripción',
                          style: DS.poppins(
                            size: 15,
                            weight: FontWeight.w700,
                            color: DS.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _description,
                          style: DS.poppins(
                            size: 13,
                            color: DS.textSecondary,
                            height: 1.65,
                          ),
                        ),
                        const SizedBox(height: 22),

                        // ─ Premium CTA ─
                        _buildPremiumBanner(context),
                        const SizedBox(height: 22),

                        // ─ Temario ─
                        _buildTemario(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoThumb() {
    final thumbUrl = (widget.course['thumbnail'] ??
            widget.course['imagen'] ??
            widget.course['image'] ??
            '')
        .toString();

    return Stack(
      children: [
        // Thumbnail or gradient placeholder
        AspectRatio(
          aspectRatio: 16 / 9,
          child: thumbUrl.isNotEmpty
              ? Image.network(
                  thumbUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _gradientThumb(),
                )
              : _gradientThumb(),
        ),
        // Dark overlay
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Color(0xAA000000)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        // Play button
        Positioned.fill(
          child: Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Color(0xFF7C3AED), size: 36),
            ),
          ),
        ),
        // "Vista previa" label
        Positioned(
          bottom: 12,
          left: 16,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Text(
              'Vista previa gratuita',
              style: DS.poppins(
                size: 11,
                weight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _gradientThumb() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2D1B69), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.play_circle_outline_rounded,
            color: Color(0x55A78BFA), size: 72),
      ),
    );
  }

  Widget _buildPremiumBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => PremiumScreen.show(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2D1B69), Color(0xFF3B1F7A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: DS.purple.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: DS.purple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Color(0xFFA78BFA), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Vuélvete Premium!',
                    style: DS.poppins(
                      size: 14,
                      weight: FontWeight.w700,
                      color: DS.textPrimary,
                    ),
                  ),
                  Text(
                    'Accede a este y todos los cursos',
                    style: DS.poppins(
                        size: 12, color: const Color(0xFFC4B5FD)),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: DS.purple,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Ver planes',
                style: DS.poppins(
                  size: 12,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemario() {
    final items = _temario;
    final shown = _temarioExpanded ? items : items.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Temario del curso',
              style: DS.poppins(
                size: 15,
                weight: FontWeight.w700,
                color: DS.textPrimary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: DS.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${items.length} temas',
                style: DS.poppins(
                  size: 11,
                  weight: FontWeight.w600,
                  color: DS.purple,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...shown.map((item) => _TemarioRow(item: item)),
        if (items.length > 3) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(
                () => _temarioExpanded = !_temarioExpanded),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: DS.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: DS.divider.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _temarioExpanded
                        ? 'Ver menos'
                        : 'Ver ${items.length - 3} temas más',
                    style: DS.poppins(
                      size: 13,
                      weight: FontWeight.w600,
                      color: DS.purple,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _temarioExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: DS.purple,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _TemarioItem {
  final int number;
  final String title;
  const _TemarioItem({required this.number, required this.title});
}

class _TemarioRow extends StatelessWidget {
  final _TemarioItem item;
  const _TemarioRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: DS.card,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: DS.divider.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: DS.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '${item.number}',
                style: DS.poppins(
                  size: 12,
                  weight: FontWeight.w700,
                  color: DS.purple,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: DS.poppins(
                  size: 13,
                  weight: FontWeight.w500,
                  color: DS.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.lock_outline_rounded,
                size: 16, color: DS.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: DS.poppins(
          size: 11,
          weight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
