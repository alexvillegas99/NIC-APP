// course_grades_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:nic_pre_u/services/course_service.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';

/// --------------------
/// Utilidades
/// --------------------
double toProgress(double? percent) {
  final v = (percent ?? 0) / 100.0;
  if (v.isNaN || v.isInfinite) return 0.0;
  final c = v.clamp(0.0, 1.0);
  return (c is double) ? c : (c as num).toDouble();
}

String fmtNum(double x) =>
    (x % 1 == 0) ? x.toStringAsFixed(0) : x.toStringAsFixed(2);

String? fmtDateISO(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  try {
    final dt = DateTime.parse(iso);
    return DateFormat('dd/MMMM/yyyy HH:mm', 'es').format(dt);
  } catch (_) {
    return iso;
  }
}

/// Calcula el % del item si:
/// 1) Viene `percentage` (string "92.5 %"/num) → úsalo
/// 2) Sino, calcula con graderaw/min/max
double? itemPercent(GradeItem it) {
  final p = GradeItem.parsePercent(it.percentage);
  if (p != null) return p.clamp(0, 100);

  final raw = GradeItem.toDouble(it.graderaw);
  final min = GradeItem.toDouble(it.min) ?? 0.0;
  final max = GradeItem.toDouble(it.max);

  if (raw == null || max == null || max <= min) return null;

  final clamped = raw.clamp(min, max);
  final ratio = (clamped - min) / (max - min);
  return (ratio * 100).clamp(0, 100);
}

/// ======================================================
/// 1) Modelo unificado de item de nota
/// ======================================================
class GradeItem {
  final int itemId;
  final String itemName;

  final dynamic grade; // texto formateado o número
  final dynamic graderaw; // número/string crudo si viene aparte
  final dynamic percentage; // "92.50 %" (string) o número
  final num? min;
  final num? max;

  /// ISO string normalizada o null
  final String? gradedAt;

  GradeItem({
    required this.itemId,
    required this.itemName,
    this.grade,
    this.graderaw,
    this.percentage,
    this.min,
    this.max,
    this.gradedAt,
  });

  factory GradeItem.fromMap(Map<String, dynamic> m) {
    try {
      final gi = GradeItem(
        itemId: m['itemId'] ?? m['itemid'] ?? 0,
        itemName: m['itemName'] ?? m['itemname'] ?? '',
        grade: m['grade'],
        graderaw: m['graderaw'] ?? m['raw'] ?? m['finalgrade'],
        percentage: m['percentage'] ?? m['percent'],
        min: (m['min'] as num?) ?? m['grademin'],
        max: (m['max'] as num?) ?? m['grademax'],
        gradedAt: _extractGradedAtISO(m),
      );
      return gi;
    } catch (e, st) {
      debugPrint('[GradeItem.fromMap] ERROR: $e\n$st\nMAP: $m');
      rethrow;
    }
  }

  static String? _extractGradedAtISO(Map<String, dynamic> m) {
    final dynamic rawTs = m['gradedategraded'] ??
        m['dategraded'] ??
        m['timemodified'] ??
        m['timecreated'] ??
        m['date'] ??
        m['gradedAt'];

    final dt = _parseFlexibleDate(rawTs);
    return dt?.toIso8601String();
  }

  static DateTime? _parseFlexibleDate(dynamic ts) {
    if (ts == null) return null;

    if (ts is num) {
      final n = ts.toInt();
      final ms = (n > 100000000 && n < 9999999999) ? n * 1000 : n;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: false);
    }

    if (ts is String) {
      final trimmed = ts.trim();

      final n = int.tryParse(trimmed);
      if (n != null) {
        final ms = (n > 100000000 && n < 9999999999) ? n * 1000 : n;
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: false);
      }

      try {
        return DateTime.parse(trimmed);
      } catch (_) {/* sigue */}

      final months = {
        'enero': 1,
        'febrero': 2,
        'marzo': 3,
        'abril': 4,
        'mayo': 5,
        'junio': 6,
        'julio': 7,
        'agosto': 8,
        'septiembre': 9,
        'setiembre': 9,
        'octubre': 10,
        'noviembre': 11,
        'diciembre': 12,
      };

      final reg = RegExp(
        r'^(\d{1,2})\s+de\s+([a-zA-Záéíóúñ]+)\s+de\s+(\d{4})(?:,\s*(\d{1,2}):(\d{2}))?$',
        caseSensitive: false,
      );
      final m = reg.firstMatch(trimmed);
      if (m != null) {
        final d = int.tryParse(m.group(1)!);
        final monName = m.group(2)!.toLowerCase();
        final y = int.tryParse(m.group(3)!);
        final hh = int.tryParse(m.group(4) ?? '0') ?? 0;
        final mm = int.tryParse(m.group(5) ?? '0') ?? 0;

        final mon = months[monName];
        if (d != null && y != null && mon != null) {
          return DateTime(y, mon, d, hh, mm);
        }
      }
    }

    return null;
  }

  static double? toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final s = v.replaceAll(',', '.').trim();
      return double.tryParse(s);
    }
    return null;
  }

  static double? parsePercent(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final s = v.replaceAll('%', '').replaceAll(',', '.').trim();
      return double.tryParse(s);
    }
    return null;
  }
}

/// ======================================================
/// 2) VM de Curso + secciones, sin tablas (robusto)
/// ======================================================
class CourseWithGrades {
  final int id;
  final String shortname;
  final String fullname;
  final String? image;

  /// Aplanado de todos los ítems
  final List<GradeItem> grades;

  /// Secciones -> items (puede incluir TOTAL con itemName vacío)
  final Map<String, List<GradeItem>> gradesBySection;

  CourseWithGrades({
    required this.id,
    required this.shortname,
    required this.fullname,
    required this.grades,
    required this.gradesBySection,
    this.image,
  });

  static String _getAsignaturaKey(Map<String, dynamic> it) {
    final direct = it['asignatura']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final idn = (it['idnumber'] ?? '').toString().trim();
    final m = RegExp(r'^([A-Za-z])\1').firstMatch(idn); // AA, BB, …
    if (m != null) return m.group(1)!.toUpperCase();
    return 'Otros';
  }

  factory CourseWithGrades.fromMap(Map<String, dynamic> m) {
    try {
      final id = (m['id'] is int) ? m['id'] : int.tryParse('${m['id']}') ?? 0;
      final shortname = m['shortname']?.toString() ?? '';
      final fullname = m['fullname']?.toString() ?? '';
      final image = (m['image'] ?? m['courseimage'])?.toString();

      final rawGrades = m['grades'];
      final Map<String, List<GradeItem>> bySection = {};
      final List<GradeItem> flat = [];

      if (rawGrades is Map) {
        rawGrades.forEach((k, v) {
          final key = k.toString();
          final list = (v is List) ? v : const [];
          final items = list
              .whereType<dynamic>()
              .map<Map<String, dynamic>>(
                  (e) => (e is Map ? Map<String, dynamic>.from(e) : {}))
              .where((mm) => mm.isNotEmpty)
              .map(GradeItem.fromMap)
              .toList();
        if (items.isNotEmpty) {
            bySection[key] = items;
            flat.addAll(items);
          }
        });
        debugPrint(
            '[CourseWithGrades.fromMap] Map secciones=${bySection.length}; flat=${flat.length}');
      } else if (rawGrades is List) {
        for (final e in rawGrades) {
          if (e is! Map) continue;
          final mm = Map<String, dynamic>.from(e);
          final gi = GradeItem.fromMap(mm);
          flat.add(gi);
          final sec = _getAsignaturaKey(mm);
          (bySection[sec] ??= []).add(gi);
        }
        debugPrint(
            '[CourseWithGrades.fromMap] List agrupado en ${bySection.length} secciones; flat=${flat.length}');
      } else {
        debugPrint(
            '[CourseWithGrades.fromMap] grades vacío o tipo=${rawGrades.runtimeType}');
      }

      bySection.removeWhere((_, v) => v.isEmpty);

      return CourseWithGrades(
        id: id,
        shortname: shortname,
        fullname: fullname,
        image: image,
        grades: flat,
        gradesBySection: bySection,
      );
    } catch (e, st) {
      debugPrint('[CourseWithGrades.fromMap] ERROR: $e\n$st\nMAP: $m');
      rethrow;
    }
  }

  /// ['A','B',...,'Otros'] con 'Otros' al final
  List<String> get secciones {
    final keys = gradesBySection.keys.toList();
    keys.sort((a, b) => a == 'Otros'
        ? 1
        : b == 'Otros'
            ? -1
            : a.compareTo(b));
    return keys;
  }
}

class SectionStats {
  final int itemsCount;
  final double? score; // suma calificados o total explícito
  final double maxCalificado;
  final double maxTotal;
  final double? percentSobreCalificados;
  final double? percentSobreTotal;
  final bool hasExplicitTotal;
  final int gradedCount;
  final int pendingCount;

  SectionStats({
    required this.itemsCount,
    required this.score,
    required this.maxCalificado,
    required this.maxTotal,
    required this.percentSobreCalificados,
    required this.percentSobreTotal,
    required this.hasExplicitTotal,
    required this.gradedCount,
    required this.pendingCount,
  });

  factory SectionStats.fromItems(List<GradeItem> items) {
    GradeItem? total;
    for (final it in items) {
      if (it.itemName.trim().isEmpty) {
        total = it;
        break;
      }
    }

    final visibles =
        items.where((g) => g.itemName.trim().isNotEmpty).toList();
    final calificados =
        visibles.where((g) => g.graderaw != null && g.max != null).toList();

    double sumMaxVisibles = 0, sumMaxCalif = 0, sumScore = 0;
    for (final it in visibles) {
      sumMaxVisibles += (GradeItem.toDouble(it.max) ?? 0);
    }
    for (final it in calificados) {
      sumMaxCalif += (GradeItem.toDouble(it.max) ?? 0);
      sumScore += (GradeItem.toDouble(it.graderaw) ?? 0);
    }

    final hasTotal = total != null;
    final baseMaxTotal =
        hasTotal ? (GradeItem.toDouble(total!.max) ?? sumMaxVisibles) : sumMaxVisibles;
    final baseScoreTotal =
        hasTotal ? (GradeItem.toDouble(total!.graderaw) ?? sumScore) : sumScore;

    final pCalif = sumMaxCalif > 0 ? (100 * sumScore / sumMaxCalif) : null;
    final pTotal = baseMaxTotal > 0 ? (100 * baseScoreTotal / baseMaxTotal) : null;

    return SectionStats(
      itemsCount: items.length,
      score: baseScoreTotal,
      maxCalificado: sumMaxCalif,
      maxTotal: baseMaxTotal,
      percentSobreCalificados:
          pCalif != null ? double.parse(pCalif.toStringAsFixed(2)) : null,
      percentSobreTotal:
          pTotal != null ? double.parse(pTotal.toStringAsFixed(2)) : null,
      hasExplicitTotal: hasTotal,
      gradedCount: calificados.length,
      pendingCount: visibles.length - calificados.length,
    );
  }
}

/// ======================================================
/// 3) Pantalla principal con 2 filtros (Sección + Actividad)
///    Filtros bonitos con chips y search redondeado
/// ======================================================
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
  late Future<CourseWithGrades?> _future;

  static const _fallbackImg =
      'https://i.pinimg.com/736x/15/bc/04/15bc04bfc0f824358e48de5a6dc2238d.jpg';

  // Filtros
  final TextEditingController _nameCtrl = TextEditingController();
  String _selectedSection = 'Todas';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<CourseWithGrades?> _load() async {
    try {
      final raw =
          widget.course ?? await widget.service.getSavedCourseById(widget.id);
      if (raw == null) {
        debugPrint('[CourseGradesScreen._load] No se encontró el curso en cache');
        return null;
      }
      debugPrint(
          '[CourseGradesScreen._load] Curso bruto keys=${raw.keys.toList()}');
      final vm = CourseWithGrades.fromMap(raw);
      debugPrint(
          '[CourseGradesScreen._load] VM listo: id=${vm.id}, fullname=${vm.fullname}, '
          'secciones=${vm.secciones.length}, totalItems=${vm.grades.length}');
      return vm;
    } catch (e, st) {
      debugPrint('[CourseGradesScreen._load] ERROR: $e\n$st');
      return null;
    }
  }

  // Título con “borde morado”
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
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title:
            const Text('Notas del curso', style: TextStyle(color: Colors.white)),
      ),
      body: FutureBuilder<CourseWithGrades?>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final course = snap.data;
          if (course == null) {
            return Center(child: Text('No se encontró el curso', style: DS.p));
          }

          // Fuente dinámica de secciones
          final sections = ['Todas', ...course.secciones];

          // Normaliza selección si desapareció en el dataset actual
          if (_selectedSection != 'Todas' &&
              !course.secciones.contains(_selectedSection)) {
            _selectedSection = 'Todas';
          }

          final title =
              course.fullname.isNotEmpty ? course.fullname : 'Curso ${widget.id}';
          final img = (course.image ?? '').trim();
          final safeImg = img.isNotEmpty ? img : _fallbackImg;

          // Secciones a renderizar según filtro
          final sectionsToShow = _selectedSection == 'Todas'
              ? course.secciones
              : course.secciones.where((s) => s == _selectedSection).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              // Header
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

              const SizedBox(height: 12),

              // ===== Filtros bonitos (Sección chips + Búsqueda) =====
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Título sutil
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Filtrar', style: DS.pDim.copyWith(fontSize: 12)),
                    ),

                    // Search redondeado
                    TextField(
                      controller: _nameCtrl,
                      onChanged: (_) => setState(() {}),
                      style: DS.p,
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre de actividad…',
                        hintStyle: DS.pDim,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0x1FFFFFFF), // leve fill
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: DS.primary),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Chips de sección (dinámico) con scroll horizontal
                    _SectionChips(
                      sections: sections,
                      selected: _selectedSection,
                      onChanged: (v) => setState(() => _selectedSection = v),
                    ),

                    // Botón limpiar alineado a la derecha
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setState(() {
                          _selectedSection = 'Todas';
                          _nameCtrl.clear();
                        }),
                        icon: const Icon(Icons.clear),
                        label: const Text('Limpiar filtros'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Secciones (filtradas)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: sectionsToShow.map((sec) {
                    final allItems =
                        course.gradesBySection[sec] ?? const <GradeItem>[];

                    // Filtro por nombre de actividad
                    final nameQuery = _nameCtrl.text.trim().toLowerCase();
                    final filteredItems = nameQuery.isEmpty
                        ? allItems
                        : allItems
                            .where((g) =>
                                g.itemName.toLowerCase().contains(nameQuery))
                            .toList();

                    final stats = SectionStats.fromItems(filteredItems);
                    final visibles = filteredItems
                        .where((g) => g.itemName.trim().isNotEmpty)
                        .toList();

                    final pctT = stats.percentSobreTotal;
                    final pctC = stats.percentSobreCalificados;
                    final score = stats.score ?? 0;
                    final maxT = stats.maxTotal;
                    final maxC = stats.maxCalificado;
                    final progress = toProgress(pctT);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: DS.card,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Encabezado de sección
                          Text('Sección $sec',
                              style: DS.h2.copyWith(fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('Total ítems: ${stats.itemsCount}',
                              style: DS.pDim),

                          const SizedBox(height: 8),

                          // Resumen textual
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Nota parcial (sobre total):', style: DS.p),
                              if (pctT != null)
                                Text(
                                  '${fmtNum(score)} / ${fmtNum(maxT)} (${fmtNum(pctT)}%)',
                                  style: DS.p,
                                )
                              else
                                Text('—', style: DS.p),

                              if (pctC != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Avance (solo calificados): '
                                  '${fmtNum(score)} / ${fmtNum(maxC)} (${fmtNum(pctC)}%)',
                                  style: DS.p,
                                ),
                              ],

                              const SizedBox(height: 4),
                              Text(
                                'Calificados: ${stats.gradedCount}  •  Pendientes: ${stats.pendingCount}',
                                style: DS.p,
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Barra principal sección
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(DS.primary),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Lista de actividades
                          if (visibles.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: DS.card,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Text(
                                nameQuery.isEmpty
                                    ? 'Sin actividades en esta sección'
                                    : 'Sin coincidencias para “$nameQuery”',
                                style: DS.pDim,
                              ),
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: visibles.map((it) {
                                final raw = GradeItem.toDouble(it.graderaw);
                                final mx = GradeItem.toDouble(it.max);
                                final dateLabel = fmtDateISO(it.gradedAt);

                                final ip = itemPercent(it); // porcentaje del ítem
                                final ipProgress = toProgress(ip);

                                return Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: DS.card,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Título
                                      Text(
                                        it.itemName.isEmpty
                                            ? '—'
                                            : it.itemName,
                                        style: DS.p,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),

                                      // Línea de datos
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            'Nota: ${raw != null ? fmtNum(raw) : (it.grade?.toString() ?? "-")}',
                                            style: DS.pDim,
                                          ),
                                          Text(
                                            'Máx: ${mx != null ? fmtNum(mx) : "—"}',
                                            style: DS.pDim,
                                          ),
                                          Text(
                                            'Fecha: ${dateLabel ?? "—"}',
                                            style: DS.pDim,
                                          ),
                                          if (ip != null)
                                            Text('(${fmtNum(ip)}%)',
                                                style: DS.pDim),
                                        ],
                                      ),

                                      // Barra de progreso del ítem (si hay %)
                                      if (ip != null) ...[
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: LinearProgressIndicator(
                                            value: ipProgress,
                                            minHeight: 6,
                                            backgroundColor: Colors.white10,
                                            // color de ítem (verde suave que combina con morado)
                                            valueColor:
                                                const AlwaysStoppedAnimation<
                                                    Color>(Color(0xFF1DE9B6)),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// ============================
/// Chips de sección (bonitos)
/// ============================
class _SectionChips extends StatelessWidget {
  final List<String> sections; // ej: ['Todas','A','B','Otros']
  final String selected;
  final ValueChanged<String> onChanged;

  const _SectionChips({
    required this.sections,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: sections.map((s) {
          final bool isActive = s == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              labelPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    s == 'Todas' ? Icons.all_inclusive : Icons.label_rounded,
                    size: 16,
                    color: isActive ? Colors.white : DS.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    s,
                    style: DS.p.copyWith(
                      color: isActive ? Colors.white : DS.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              selected: isActive,
              backgroundColor: const Color(0x1AFFFFFF), // 10% blanco
              selectedColor: DS.primary,
              shape: StadiumBorder(
                side: BorderSide(
                  color: isActive ? DS.primary : Colors.white12,
                ),
              ),
              onSelected: (_) => onChanged(s),
            ),
          );
        }).toList(),
      ),
    );
  }
}
