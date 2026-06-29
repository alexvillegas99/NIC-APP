import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nic_pre_u/services/auth_service.dart';
import 'package:nic_pre_u/services/asistentes_service.dart';

/// Se lanza cuando el backend rechaza el token (401). En este backend el login
/// es single-session: si el estudiante inició sesión en otro lado (p. ej. la web
/// para subir su foto), el token del app queda invalidado y hay que re-loguear.
class SesionExpiradaHorario implements Exception {}

/// Acceso a una clase virtual / grupo (links de Zoom y WhatsApp).
class AccesoClase {
  final String grupo;
  final String sede;
  final String? virtualLink;
  final List<String> whatsapps;

  AccesoClase({
    required this.grupo,
    required this.sede,
    this.virtualLink,
    this.whatsapps = const [],
  });

  factory AccesoClase.fromJson(Map<String, dynamic> j) => AccesoClase(
        grupo: (j['grupo'] ?? '').toString(),
        sede: (j['sede'] ?? '').toString(),
        virtualLink: (j['virtualLink'] ?? '').toString().isEmpty
            ? null
            : j['virtualLink'].toString(),
        whatsapps: ((j['whatsapps'] as List?) ?? const [])
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList(),
      );
}

/// Resultado del horario del estudiante listo para pintar.
class HorarioEstudiante {
  /// weekday (1=Lun … 7=Dom) → lista de clases (ordenadas por hora).
  /// Cada clase usa las mismas claves que el horario viejo:
  /// 'Hora inicio', 'Hora fin', 'Materia', 'Aula', 'Profesor', 'Modalidad'
  /// más extras: 'Paralelo', 'Universidad'.
  final Map<int, List<Map<String, dynamic>>> porDia;
  final List<AccesoClase> accesos;
  final String? opcion1;
  final String? opcion2;
  final String? opcion3;
  final bool desdeBackendNuevo;
  final bool publicado;
  /// El token fue rechazado (401): la sesión expiró → re-loguear.
  final bool sesionExpirada;

  HorarioEstudiante({
    required this.porDia,
    this.accesos = const [],
    this.opcion1,
    this.opcion2,
    this.opcion3,
    this.desdeBackendNuevo = false,
    this.publicado = true,
    this.sesionExpirada = false,
  });

  bool get vacio => porDia.values.every((l) => l.isEmpty);
}

class HorarioService {
  final String base = dotenv.env['API_URL'] ?? '';
  final AuthService _auth = AuthService();
  final AsistentesService _asistentes = AsistentesService();

  static const _diaCodeToWd = {
    'L': 1, 'M': 2, 'X': 3, 'J': 4, 'V': 5, 'S': 6, 'D': 7,
  };

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Carga el horario del estudiante logueado.
  /// 1) Intenta GET /horarios/mi-horario (sistema nuevo de horarios).
  /// 2) Si no hay datos, cae al horario embebido en los cursos (legacy).
  Future<HorarioEstudiante> cargar() async {
    try {
      final nuevo = await _miHorario();
      if (nuevo != null && !nuevo.vacio) return nuevo;
      // Publicado pero sin clases: igual devolvemos el nuevo (vacío real).
      if (nuevo != null && nuevo.desdeBackendNuevo && nuevo.publicado) {
        // Aún así intentamos legacy por si el alumno está en el sistema viejo.
        final legacy = await _legacy();
        if (!legacy.vacio) return legacy;
        return nuevo;
      }
    } on SesionExpiradaHorario {
      // Token rechazado (single-session): la pantalla mostrará "sesión expirada".
      return HorarioEstudiante(porDia: {}, sesionExpirada: true);
    } catch (_) {
      // Timeout u otro error → caemos al horario legacy.
    }
    return _legacy();
  }

  Future<HorarioEstudiante?> _miHorario() async {
    final uri = Uri.parse('$base/horarios/mi-horario');
    // mi-horario es un endpoint PESADO (muchas consultas a BD): le damos
    // margen amplio para que no se corte y caiga al legacy injustificadamente.
    final res = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 25));
    if (res.statusCode == 401) throw SesionExpiradaHorario();
    if (res.statusCode != 200) return null;

    final body = json.decode(res.body);
    if (body is! Map) return null;
    final data = body['data'];
    if (data == null) return null; // null → no es alumno del sistema nuevo
    if (data is! Map) return null;

    final grid = (data['grid'] as List?) ?? const [];
    final entries = (data['entries'] as List?) ?? const [];
    final publicado = !(entries.isEmpty && grid.isEmpty);

    final Map<int, List<Map<String, dynamic>>> porDia = {};
    for (final g in grid) {
      if (g is! Map) continue;
      final wd = _diaCodeToWd[(g['dia'] ?? '').toString().toUpperCase()];
      if (wd == null) continue;
      final franja = (g['franja'] ?? '').toString();
      final partes = franja.split('-');
      final inicio = partes.isNotEmpty ? partes[0].trim() : '';
      final fin = partes.length > 1 ? partes[1].trim() : '';
      porDia.putIfAbsent(wd, () => []);
      porDia[wd]!.add({
        'Hora inicio': inicio,
        'Hora fin': fin,
        'Materia': (g['materia'] ?? '').toString(),
        'Aula': (g['aula'] ?? '').toString(),
        'Profesor': (g['profesor'] ?? '').toString(),
        'Modalidad': (g['modalidad'] ?? '').toString(),
        'Paralelo': (g['paralelo'] ?? '').toString(),
        'Universidad': (g['universidad'] ?? g['etiquetaUni'] ?? '').toString(),
      });
    }
    for (final l in porDia.values) {
      l.sort((a, b) =>
          (a['Hora inicio'] ?? '').compareTo(b['Hora inicio'] ?? ''));
    }

    final accesos = ((data['accesos'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => AccesoClase.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return HorarioEstudiante(
      porDia: porDia,
      accesos: accesos,
      opcion1: data['opcion1']?.toString(),
      opcion2: data['opcion2']?.toString(),
      opcion3: data['opcion3']?.toString(),
      desdeBackendNuevo: true,
      publicado: publicado,
    );
  }

  /// Horario legacy embebido en los cursos del estudiante.
  Future<HorarioEstudiante> _legacy() async {
    const dayNameToWd = {
      'Lunes': 1, 'Martes': 2, 'Miercoles': 3, 'Miércoles': 3,
      'Jueves': 4, 'Viernes': 5, 'Sabado': 6, 'Sábado': 6, 'Domingo': 7,
    };
    final cursos = await _asistentes.fetchCursosPorCedula();
    final Map<int, List<Map<String, dynamic>>> porDia = {};
    for (final curso in cursos) {
      final horario = curso['horario'];
      if (horario is! List) continue;
      final nombre = (curso['nombre'] ?? '')
          .toString()
          .replaceAll('_', ' ')
          .replaceAll('-', ' ');
      final seen = <String>{};
      for (final h in horario) {
        if (h is! Map) continue;
        final wd = dayNameToWd[(h['Dia'] ?? '').toString()];
        if (wd == null) continue;
        final key =
            '${h['Dia']}|${h['Hora inicio']}|${h['Hora fin']}|${h['Materia']}|${h['Aula']}';
        if (seen.contains(key)) continue;
        seen.add(key);
        porDia.putIfAbsent(wd, () => []);
        porDia[wd]!
            .add({...Map<String, dynamic>.from(h), 'Materia': h['Materia'] ?? nombre, '_cursoNombre': nombre});
      }
    }
    for (final l in porDia.values) {
      l.sort((a, b) =>
          (a['Hora inicio'] ?? '').compareTo(b['Hora inicio'] ?? ''));
    }
    return HorarioEstudiante(porDia: porDia, desdeBackendNuevo: false);
  }
}
