class GradeItem {
  final int itemId;
  final String itemName;

  /// Texto de calificación formateada (puede ser "-")
  final dynamic grade;

  /// Nota cruda (número/string) cuando viene aparte
  final dynamic graderaw;

  /// "92.50 %" (string) o número, según el backend
  final dynamic percentage;

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

  /// Intenta extraer una fecha desde varias llaves comunes y normaliza a ISO.
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

  factory GradeItem.fromMap(Map<String, dynamic> m) => GradeItem(
        itemId: m['itemId'] ?? m['itemid'] ?? 0,
        itemName: m['itemName'] ?? m['itemname'] ?? '',
        grade: m['grade'],
        graderaw: m['graderaw'],
        percentage: m['percentage'],
        min: (m['min'] as num?) ?? m['grademin'],
        max: (m['max'] as num?) ?? m['grademax'],
        gradedAt: _extractGradedAtISO(m),
      );

  /// ===== Helpers estáticos =====

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

  /// Acepta:
  /// - int/num (epoch s o ms)
  /// - ISO-8601
  /// - “19 de septiembre de 2025, 16:30” (ES)
  static DateTime? _parseFlexibleDate(dynamic ts) {
    if (ts == null) return null;

    // num/epoch
    if (ts is num) {
      final n = ts.toInt();
      final ms = (n > 100000000 && n < 9999999999) ? n * 1000 : n;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: false);
    }

    if (ts is String) {
      final trimmed = ts.trim();

      // ¿entero?
      final n = int.tryParse(trimmed);
      if (n != null) {
        final ms = (n > 100000000 && n < 9999999999) ? n * 1000 : n;
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: false);
      }

      // ¿ISO?
      try {
        return DateTime.parse(trimmed);
      } catch (_) {/* sigue */}

      // ¿Español “19 de septiembre de 2025, 16:30”?
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
        'setiembre': 9, // por si acaso
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
}
