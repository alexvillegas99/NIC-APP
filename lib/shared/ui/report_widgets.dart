// lib/shared/ui/report_widgets.dart
import 'package:flutter/material.dart';

class Header extends StatelessWidget {
  final String title;
  final String subtitle;
  const Header({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: reportCardDeco(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                color: Color(0xFFEDEDED),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                color: Color(0xFF9EA3B0),
                fontSize: 13.5,
              )),
        ],
      ),
    );
  }
}

class ActionRow extends StatelessWidget {
  final VoidCallback? onDownloadPdf;
  const ActionRow({super.key, this.onDownloadPdf});

  @override
  Widget build(BuildContext context) {
    if (onDownloadPdf == null) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onDownloadPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Descargar PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PlaceholderCard extends StatelessWidget {
  final String title;
  final List<String> lines;
  const PlaceholderCard({super.key, required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: reportCardDeco(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                color: Color(0xFFEDEDED),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 8),
          ...lines.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                l,
                style: const TextStyle(
                  color: Color(0xFF9EA3B0),
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration reportCardDeco() {
  return BoxDecoration(
    color: const Color(0xFF111320).withOpacity(0.85),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xFF1D2136)),
  );
}
Widget courseHeader(Map<String, dynamic> curso, Map<String, dynamic> resumen) {
  final nombre = (curso['nombre'] ?? '') as String;
  final estado = (curso['estado'] ?? '') as String;
  final diasActuales = (curso['diasActuales'] ?? 0) as int;
  final diasCurso = (curso['diasCurso'] ?? 0) as int;
  final imagen = curso['imagen'] as String?;
  final porcentaje = (resumen['porcentajeAsistencia'] ?? 0) as int;

  return Container(
    decoration: reportCardDeco(),
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        if (imagen != null && imagen.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(imagen, width: 64, height: 64, fit: BoxFit.cover),
          )
        else
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF1D2136), borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.school_outlined, color: Colors.white),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombre, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFEDEDED), fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Chip(
                    label: Text(estado.isEmpty ? '—' : estado),
                    backgroundColor: estado == 'Activo' ? Colors.green.withOpacity(.15) : Colors.grey.withOpacity(.2),
                    labelStyle: TextStyle(color: estado == 'Activo' ? Colors.green : Colors.grey),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 8),
                  Text('Días: $diasActuales/$diasCurso',
                    style: const TextStyle(color: Color(0xFF9EA3B0), fontSize: 12.5)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: diasCurso > 0 ? (diasActuales / diasCurso).clamp(0, 1) : 0,
                backgroundColor: const Color(0xFF1D2136),
              ),
              const SizedBox(height: 6),
              Text('Asistencia: $porcentaje%',
                style: const TextStyle(color: Color(0xFF9EA3B0), fontSize: 12.5)),
            ],
          ),
        ),
      ],
    ),
  );
}



class DayAttendanceTile extends StatelessWidget {
  final String fecha;          // 'YYYY-MM-DD'
  final List<String> horas;    // ['07:29:02','14:12:15',...]

  const DayAttendanceTile({
    super.key,
    required this.fecha,
    required this.horas,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: reportCardDeco(),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fecha
          Text(
            fecha,
            style: const TextStyle(
              color: Color(0xFFEDEDED),
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),

          // Chips de horas
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(horas.length, (i) {
              final h = horas[i];
              final isEntrada = i == 0;
              final isSalida  = i == 1;
              final label = isEntrada
                  ? 'Entrada $h'
                  : isSalida
                      ? 'Salida $h'
                      : 'Registro ${i + 1} $h';

              final Color base = isEntrada
                  ? Colors.blueAccent
                  : isSalida
                      ? Colors.orange
                      : Colors.grey;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: base.withOpacity(.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: base.withOpacity(.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isEntrada
                          ? Icons.login
                          : isSalida
                              ? Icons.logout
                              : Icons.schedule,
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(color: Color(0xFFEDEDED), fontSize: 12.5),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

String formatCourseName(String? raw) {
  final s = (raw ?? '').replaceAll('_', ' ');
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}class CourseHeaderCard extends StatelessWidget {
  final String courseNameRaw;
  final String? assistantName;
  final String estado;

  /// 👇 Nuevo: días asistidos y días de clase (dictados)
  final int attendedDays; // = resumen.diasConAsistencia
  final int classDays;    // = curso.diasActuales

  final int? porcentajeAsistencia;

  const CourseHeaderCard({
    super.key,
    required this.courseNameRaw,
    this.assistantName,
    required this.estado,
    required this.attendedDays,
    required this.classDays,
    this.porcentajeAsistencia,
  });

  @override
  Widget build(BuildContext context) {
    final courseName = formatCourseName(courseNameRaw);
    final ratio = classDays > 0 ? (attendedDays / classDays).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: reportCardDeco(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nombre del curso
          Text(
            courseName.isEmpty ? '—' : courseName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFEDEDED),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),

          // Nombre del asistente (si existe)
          if ((assistantName ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              assistantName!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF9EA3B0),
                fontSize: 13.5,
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Estado + Días (Asistidos / Clases dictadas)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: estado == 'Activo'
                      ? Colors.green.withOpacity(.15)
                      : Colors.grey.withOpacity(.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  estado.isEmpty ? '—' : estado,
                  style: TextStyle(
                    color: estado == 'Activo' ? Colors.green : Colors.grey,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Asistidos: $attendedDays / Clases: $classDays',
                style: const TextStyle(color: Color(0xFF9EA3B0), fontSize: 12.5),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progreso en función de días asistidos vs clases dictadas
          LinearProgressIndicator(
            value: ratio,
            backgroundColor: const Color(0xFF1D2136),
            minHeight: 6,
          ),

          if (porcentajeAsistencia != null) ...[
            const SizedBox(height: 6),
            Text(
              'Asistencia: ${porcentajeAsistencia}%',
              style: const TextStyle(color: Color(0xFF9EA3B0), fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}