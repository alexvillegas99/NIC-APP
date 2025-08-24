import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:nic_pre_u/services/course_service.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';

class CourseGradesScreen extends StatefulWidget {
  final int id;
  final Map<String, dynamic>? course; // puede llegar por extra
  final CourseService service;

  const CourseGradesScreen({
    super.key,
    required this.id,
    required this.service,
    this.course,
  });

  @override
  State<CourseGradesScreen> createState() => _CourseGradesScreenState();
}

class _CourseGradesScreenState extends State<CourseGradesScreen> {
  late Future<Map<String, dynamic>?> _future;

  static const _fallbackImg =
      'https://i.pinimg.com/736x/15/bc/04/15bc04bfc0f824358e48de5a6dc2238d.jpg';

  @override
  void initState() {
    super.initState();
    _future = widget.course != null
        ? Future.value(widget.course)
        : widget.service.getSavedCourseById(widget.id);
  }

  // helpers números/porcentajes
  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final s = v.replaceAll(',', '.').trim();
      return double.tryParse(s);
    }
    return null;
  }

  double? _parsePercent(dynamic percent) {
    if (percent == null) return null;
    if (percent is num) return percent.toDouble();
    if (percent is String) {
      final s = percent.replaceAll('%', '').replaceAll(',', '.').trim();
      return double.tryParse(s);
    }
    return null;
  }

  // dd/MMMM/yyyy hh:mm para gradedategraded/otros timestamps
  String? _formatDate(Map<String, dynamic> g) {
    dynamic ts = g['gradedategraded'] ??
        g['dategraded'] ??
        g['timemodified'] ??
        g['timecreated'] ??
        g['date'];

    if (ts == null) return null;

    int? millis;

    if (ts is int) {
      // Si parece epoch en segundos → a ms
      millis = (ts > 100000000 && ts < 9999999999) ? ts * 1000 : ts;
    } else if (ts is String) {
      // Primero intenta como entero
      final n = int.tryParse(ts);
      if (n != null) {
        millis = (n > 100000000 && n < 9999999999) ? n * 1000 : n;
      } else {
        // Luego intenta ISO-8601
        try {
          final dt = DateTime.parse(ts);
          return DateFormat('dd/MMMM/yyyy hh:mm', 'es').format(dt);
        } catch (_) {
          return ts; // último recurso: devolver tal cual
        }
      }
    }

    if (millis == null) return ts.toString();

    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return DateFormat('dd/MMMM/yyyy hh:mm', 'es').format(dt);
  }

  // Título con “borde morado” (outline)
  Widget _outlinedText(
    String text, {
    required TextStyle style,
    Color strokeColor = const Color(0xFF7C3AED),
    double strokeWidth = 2.0,
  }) {
    return Stack(
      children: [
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = strokeColor,
          ),
        ),
        Text(text, style: style),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DS.bg,
      appBar: AppBar(
        backgroundColor: DS.card,
        iconTheme: const IconThemeData(color: Colors.white), // flecha blanca
        actionsIconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: const Text('Notas del curso', style: TextStyle(color: Colors.white)),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final c = snap.data;
          if (c == null) {
            return Center(child: Text('No se encontró el curso', style: DS.p));
          }

          final title = (c['fullname'] as String?) ?? 'Curso ${widget.id}';
          final img = (c['image'] as String?)?.trim();
          final safeImg = (img != null && img.isNotEmpty) ? img : _fallbackImg;
          final grades = (c['grades'] as List? ?? [])
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              // Header con imagen + SOLO fullname con borde morado
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                child: Stack(
                  alignment: Alignment.bottomLeft,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        safeImg,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.white10),
                      ),
                    ),
                    // Overlay degradado
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, DS.bg.withOpacity(0.95)],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _outlinedText(
                        title,
                        style: DS.h2.copyWith(fontSize: 22),
                        strokeWidth: 2.2,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Ítems de calificación', style: DS.h2),
              ),
              const SizedBox(height: 10),

              if (grades.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Aún sin calificaciones.', style: DS.pDim),
                )
              else
                ...grades.map((g) => _GradeTile(
                      name: (g['itemName'] ?? g['itemname'] ?? '') as String,
                      grade: g['grade'],
                      graderaw: g['graderaw'], // 👈 NUEVO
                      percentage: g['percentage'],
                      min: _toDouble(g['min']) ?? _toDouble(g['grademin']),
                      max: _toDouble(g['max']) ?? _toDouble(g['grademax']),
                      dateLabel: _formatDate(g),
                      parsePercent: _parsePercent,
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _GradeTile extends StatelessWidget {
  final String name;
  final dynamic grade;          // formateado (puede ser "-")
  final dynamic graderaw;       // crudo (num/string)
  final dynamic percentage;     // ej. "85.00 %"
  final double? min;
  final double? max;
  final String? dateLabel;
  final double? Function(dynamic) parsePercent;

  const _GradeTile({
    required this.name,
    required this.grade,
    required this.graderaw,
    required this.percentage,
    required this.min,
    required this.max,
    required this.dateLabel,
    required this.parsePercent,
  });

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final s = v.replaceAll(',', '.').trim();
      return double.tryParse(s);
    }
    return null;
  }

  bool get _hasRealGrade =>
      !(grade is String && (grade as String).trim() == '-');

  String _fmtNum(double x) =>
      (x % 1 == 0) ? x.toStringAsFixed(0) : x.toStringAsFixed(2);

  Widget _gradeBadge(String main, {required bool highlight}) {
    final Color border = highlight ? DS.primary : Colors.white24;
    final Color bg = highlight ? DS.primary.withOpacity(0.12) : Colors.white10;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Text(
        main,
        style: DS.p.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (name.isEmpty) ? 'Actividad sin nombre' : name;

    // Preferimos porcentaje para el badge; si no hay, mostramos solo la nota.
    final raw = _toDouble(graderaw);
    final g = _toDouble(grade);
    final p = parsePercent(percentage);

    double? progress;
    String mainBadge;

    if (p != null) {
      // Badge SOLO porcentaje, y progreso por %.
      progress = (p / 100).clamp(0, 1);
      mainBadge = '${_fmtNum(p)} %';
    } else if (raw != null && min != null && max != null && max! > min!) {
      // Sin %, usar nota cruda para progreso; badge SOLO número.
      final clamped = raw.clamp(min!, max!);
      progress = (clamped - min!) / (max! - min!);
      mainBadge = _fmtNum(raw);
    } else if (g != null && min != null && max != null && max! > min!) {
      final clamped = g.clamp(min!, max!);
      progress = (clamped - min!) / (max! - min!);
      mainBadge = _fmtNum(g);
    } else if (raw != null) {
      mainBadge = _fmtNum(raw);
    } else if (g != null) {
      mainBadge = _fmtNum(g);
    } else {
      mainBadge = (grade is String && grade.trim().isNotEmpty)
          ? grade as String
          : '-';
    }

    final bool highlight = p != null || raw != null || _hasRealGrade;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DS.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // título y badge (solo % o solo nota)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: DS.p,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              _gradeBadge(mainBadge, highlight: highlight),
            ],
          ),
          const SizedBox(height: 8),

          // barra de progreso si tenemos valor (por % o por nota relativa)
          if (progress != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(DS.primary),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                if (max != null) Text('Máx: ${_fmtNum(max!)}', style: DS.pDim),
                if (raw != null) Text('Nota: ${_fmtNum(raw)}', style: DS.pDim),
              ],
            ),
          ],

          // fecha (solo si hay algún valor real)
          if (dateLabel != null &&
              dateLabel!.trim().isNotEmpty &&
              (p != null || raw != null || _hasRealGrade)) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.event, size: 16, color: DS.primary.withOpacity(0.85)),
                const SizedBox(width: 6),
                Text('Fecha: $dateLabel', style: DS.pDim),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
