import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Tipo de actividad que el estudiante puede retomar desde el home.
enum ActividadKind { simulador, curso }

/// Última actividad del estudiante para la tarjeta "Continúa donde lo dejaste"
/// del home (estilo Headway). Se guarda localmente al abrir un simulador o un
/// curso; el home lee la más reciente para ofrecer retomarla con un toque.
class UltimaActividad {
  final ActividadKind kind;
  final String title;
  final String subtitle;
  final Map<String, dynamic>? sim; // SimCatalogItem.toJson() si es simulador
  final DateTime ts;

  UltimaActividad({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.ts,
    this.sim,
  });

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'title': title,
        'subtitle': subtitle,
        'ts': ts.toIso8601String(),
        if (sim != null) 'sim': sim,
      };

  static UltimaActividad? fromJson(Map<String, dynamic> j) {
    final kindStr = (j['kind'] ?? '').toString();
    ActividadKind? kind;
    for (final k in ActividadKind.values) {
      if (k.name == kindStr) {
        kind = k;
        break;
      }
    }
    if (kind == null) return null;
    return UltimaActividad(
      kind: kind,
      title: (j['title'] ?? '').toString(),
      subtitle: (j['subtitle'] ?? '').toString(),
      ts: DateTime.tryParse((j['ts'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      sim: j['sim'] is Map ? Map<String, dynamic>.from(j['sim'] as Map) : null,
    );
  }
}

class LastActivityService {
  static const _key = 'last_activity_v1';

  Future<void> _save(UltimaActividad a) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(a.toJson()));
  }

  Future<void> recordSimulador({
    required String title,
    required String subtitle,
    required Map<String, dynamic> sim,
  }) =>
      _save(UltimaActividad(
        kind: ActividadKind.simulador,
        title: title,
        subtitle: subtitle,
        sim: sim,
        ts: DateTime.now(),
      ));

  Future<void> recordCurso({required String title, String subtitle = ''}) =>
      _save(UltimaActividad(
        kind: ActividadKind.curso,
        title: title,
        subtitle: subtitle,
        ts: DateTime.now(),
      ));

  Future<UltimaActividad?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw);
      if (j is Map) {
        return UltimaActividad.fromJson(Map<String, dynamic>.from(j));
      }
    } catch (_) {}
    return null;
  }
}
