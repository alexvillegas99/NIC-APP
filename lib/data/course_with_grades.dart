import 'grade_item.dart';

class CourseWithGrades {
  final int id;
  final String shortname;
  final String fullname;
  final String? image;

  /// Si vino en lista plana, aquí guardamos TODO; si vino por secciones, lo aplanamos.
  final List<GradeItem> grades;

  /// Secciones -> items (incluye el posible “total” con itemName vacío)
  final Map<String, List<GradeItem>> gradesBySection;

  CourseWithGrades({
    required this.id,
    required this.shortname,
    required this.fullname,
    required this.grades,
    required this.gradesBySection,
    this.image,
  });

  /// --- Heurística para deducir sección (A, B, …) desde cada item ---
  static String _getAsignaturaKey(Map<String, dynamic> it) {
    final direct = it['asignatura']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final idn = (it['idnumber'] ?? '').toString().trim();
    final m = RegExp(r'^([A-Za-z])\1').firstMatch(idn); // AA, BB, …
    if (m != null) return m.group(1)!.toUpperCase();
    return 'Otros';
  }

  /// --- Crea desde respuesta flexible ---
  factory CourseWithGrades.fromMap(Map<String, dynamic> m) {
    final id = (m['id'] is int) ? m['id'] : int.tryParse('${m['id']}') ?? 0;
    final shortname = m['shortname']?.toString() ?? '';
    final fullname  = m['fullname']?.toString() ?? '';
    final image     = m['image']?.toString();

    final rawGrades = m['grades'];

    final Map<String, List<GradeItem>> bySection = {};
    final List<GradeItem> flat = [];

    if (rawGrades is Map) {
      // Caso ideal: { A:[], B:[], Otros:[] }
      rawGrades.forEach((k, v) {
        final key = k.toString();
        final list = (v is List) ? v : const [];
        final items = list
            .whereType<dynamic>()
            .map<Map<String, dynamic>>((e) => (e is Map ? Map<String, dynamic>.from(e) : {}))
            .where((mm) => mm.isNotEmpty)
            .map(GradeItem.fromMap)
            .toList();
        if (items.isNotEmpty) {
          bySection[key] = items;
          flat.addAll(items);
        }
      });
    } else if (rawGrades is List) {
      // Plano ⇒ agrupar con heurística
      for (final e in rawGrades) {
        if (e is! Map) continue;
        final mm = Map<String, dynamic>.from(e);
        final gi = GradeItem.fromMap(mm);
        flat.add(gi);
        final sec = _getAsignaturaKey(mm);
        (bySection[sec] ??= []).add(gi);
      }
    }

    // Limpia secciones vacías
    bySection.removeWhere((_, v) => v.isEmpty);

    return CourseWithGrades(
      id: id,
      shortname: shortname,
      fullname: fullname,
      image: image,
      grades: flat,
      gradesBySection: bySection,
    );
  }

  /// Devuelve ['A','B',...,'Otros'] con 'Otros' al final.
  List<String> get secciones {
    final keys = gradesBySection.keys.toList();
    keys.sort((a, b) => a == 'Otros'
        ? 1
        : b == 'Otros'
            ? -1
            : a.compareTo(b));
    return keys;
  }

  /// Items (de la sección) visibles en tabla: excluye el “total” (itemName vacío)
  List<GradeItem> getSectionItemsVisible(String seccion) {
    final all = gradesBySection[seccion] ?? const <GradeItem>[];
    return all.where((g) => g.itemName.trim().isNotEmpty).toList();
  }
}

/// ======================
/// Stats por sección (como Angular)
/// ======================
class SectionStats {
  final int itemsCount;
  final double? score;               // suma de calificados (o del total explícito si aplica)
  final double maxCalificado;        // base de calificados (suma max de calificados)
  final double maxTotal;             // base total (o max del total explícito)
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
    // Ítem “total” (itemName vacío)
    GradeItem? total;
    for (final it in items) {
      if (it.itemName.trim().isEmpty) {
        total = it;
        break;
      }
    }

    final visibles = items.where((g) => g.itemName.trim().isNotEmpty).toList();
    final calificados = visibles.where((g) => g.graderaw != null && g.max != null).toList();

    double sumMaxVisibles = 0, sumMaxCalif = 0, sumScore = 0;
    for (final it in visibles) {
      sumMaxVisibles += (GradeItem.toDouble(it.max) ?? 0);
    }
    for (final it in calificados) {
      sumMaxCalif += (GradeItem.toDouble(it.max) ?? 0);
      sumScore    += (GradeItem.toDouble(it.graderaw) ?? 0);
    }

    final hasTotal = total != null;
    final baseMaxTotal   = hasTotal ? (GradeItem.toDouble(total!.max) ?? sumMaxVisibles) : sumMaxVisibles;
    final baseScoreTotal = hasTotal ? (GradeItem.toDouble(total!.graderaw) ?? sumScore) : sumScore;

    final pCalif = sumMaxCalif > 0 ? (100 * sumScore / sumMaxCalif) : null;
    final pTotal = baseMaxTotal > 0 ? (100 * baseScoreTotal / baseMaxTotal) : null;

    return SectionStats(
      itemsCount: items.length,
      score: baseScoreTotal,
      maxCalificado: sumMaxCalif,
      maxTotal: baseMaxTotal,
      percentSobreCalificados: pCalif != null ? double.parse(pCalif.toStringAsFixed(2)) : null,
      percentSobreTotal: pTotal != null ? double.parse(pTotal.toStringAsFixed(2)) : null,
      hasExplicitTotal: hasTotal,
      gradedCount: calificados.length,
      pendingCount: visibles.length - calificados.length,
    );
  }
}

/// ======================
/// Filtros (nombre y rango fechas)
/// ======================
class SectionFilters {
  String nombre = '';
  DateTime? desde; // inclusive 00:00
  DateTime? hasta; // inclusive 23:59:59
}

extension GradeFilters on List<GradeItem> {
  List<GradeItem> applyFilters(SectionFilters f) {
    return where((it) {
      if (f.nombre.trim().isNotEmpty) {
        if (!it.itemName.toLowerCase().contains(f.nombre.trim().toLowerCase())) {
          return false;
        }
      }
      if (f.desde != null || f.hasta != null) {
        DateTime? dt;
        if (it.gradedAt != null) {
          try { dt = DateTime.parse(it.gradedAt!); } catch (_) {}
        }
        if (f.desde != null && (dt == null || dt.isBefore(f.desde!))) return false;
        if (f.hasta != null && (dt == null || dt.isAfter(f.hasta!)))  return false;
      }
      return true;
    }).toList();
  }
}
