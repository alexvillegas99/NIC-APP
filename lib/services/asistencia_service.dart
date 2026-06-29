// lib/services/asistencia_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nic_pre_u/services/auth_service.dart';

class AsistenciaCurso {
  final String? id;
  final String? nombre;
  final String? estado;
  final int? diasActuales;
  final int? diasCurso;
  final String? updatedAt;
  final String? imagen;

  AsistenciaCurso({
    this.id,
    this.nombre,
    this.estado,
    this.diasActuales,
    this.diasCurso,
    this.updatedAt,
    this.imagen,
  });

  factory AsistenciaCurso.fromJson(Map<String, dynamic> j) => AsistenciaCurso(
    id: j['id']?.toString(),
    nombre: j['nombre']?.toString(),
    estado: j['estado']?.toString(),
    diasActuales: (j['diasActuales'] as num?)?.toInt(),
    diasCurso: (j['diasCurso'] as num?)?.toInt(),
    updatedAt: j['updatedAt']?.toString(),
    imagen: j['imagen']?.toString(),
  );
}

class AsistenciaResumen {
  final int totalRegistros;
  final String? ultimaFecha;
  final int diasConAsistencia;
  final int porcentajeAsistencia;
  final int totalAsistenciasAcumuladas;

  // NUEVOS
  final int totalDiasEsperados;
  final int totalFaltas;

  AsistenciaResumen({
    required this.totalRegistros,
    required this.ultimaFecha,
    required this.diasConAsistencia,
    required this.porcentajeAsistencia,
    required this.totalAsistenciasAcumuladas,
    required this.totalDiasEsperados,
    required this.totalFaltas,
  });

  factory AsistenciaResumen.fromJson(Map<String, dynamic> j) =>
      AsistenciaResumen(
        totalRegistros: (j['totalRegistros'] as num? ?? 0).toInt(),
        ultimaFecha: j['ultimaFecha']?.toString(),
        diasConAsistencia: (j['diasConAsistencia'] as num? ?? 0).toInt(),
        porcentajeAsistencia: (j['porcentajeAsistencia'] as num? ?? 0).toInt(),
        totalAsistenciasAcumuladas:
            (j['totalAsistenciasAcumuladas'] as num? ?? 0).toInt(),
        totalDiasEsperados: (j['totalDiasEsperados'] as num? ?? 0).toInt(),
        totalFaltas: (j['totalFaltas'] as num? ?? 0).toInt(),
      );
}

class AsistenciaFaltas {
  final String? referencia;
  final List<String> diasFaltados;

  AsistenciaFaltas({required this.referencia, required this.diasFaltados});

  factory AsistenciaFaltas.fromJson(Map<String, dynamic> j) => AsistenciaFaltas(
    referencia: j['referencia']?.toString(),
    diasFaltados: ((j['diasFaltados'] as List?) ?? const [])
        .map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList(),
  );
}

class AsistenciaRegistro {
  final String fecha; // YYYY-MM-DD
  final List<String> horas; // ['08:00:00', ...]
  final int registrosEnElDia; // NUEVO

  AsistenciaRegistro({
    required this.fecha,
    required this.horas,
    required this.registrosEnElDia,
  });

  factory AsistenciaRegistro.fromJson(Map<String, dynamic> j) =>
      AsistenciaRegistro(
        fecha: j['fecha']?.toString() ?? '',
        horas: ((j['horas'] as List?) ?? const [])
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList(),
        registrosEnElDia: (j['registrosEnElDia'] as num? ?? 0).toInt(),
      );
}

class AsistenciaReporte {
  final String cedula;
  final String? asistenteId;
  final String? asistenteNombre;
  final AsistenciaCurso curso;
  final AsistenciaResumen resumen;
  final List<AsistenciaRegistro> registros;

  // NUEVO
  final AsistenciaFaltas? faltas;

  AsistenciaReporte({
    required this.cedula,
    this.asistenteId,
    this.asistenteNombre,
    required this.curso,
    required this.resumen,
    required this.registros,
    this.faltas,
  });

  factory AsistenciaReporte.fromJson(
    Map<String, dynamic> j,
  ) => AsistenciaReporte(
    cedula: j['cedula']?.toString() ?? '',
    asistenteId: j['asistente']?['id']?.toString(),
    asistenteNombre: j['asistente']?['nombre']?.toString(),
    curso: AsistenciaCurso.fromJson((j['curso'] ?? {}) as Map<String, dynamic>),
    resumen: AsistenciaResumen.fromJson(
      (j['resumen'] ?? {}) as Map<String, dynamic>,
    ),
    registros: ((j['registros'] as List?) ?? const [])
        .map(
          (e) => AsistenciaRegistro.fromJson((e ?? {}) as Map<String, dynamic>),
        )
        .toList(),
    faltas: j['faltas'] == null
        ? null
        : AsistenciaFaltas.fromJson(
            (j['faltas'] ?? {}) as Map<String, dynamic>,
          ),
  );
}

class AsistenciaService {
  final String base = dotenv.env['API_URL'] ?? '';
  final AuthService _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<AsistenciaReporte> getPorCedula({
    required String cedula,
    required String cursoId,
  }) async {
    final uri = Uri.parse(
      '$base/asistencias/por-cedula?cedula=$cedula&cursoId=$cursoId',
    );

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    return AsistenciaReporte.fromJson(data);
  }

  /// Si el PDF lo genera el backend (recomendado)
Uri buildPdfUri(
  String cedula, {
  required String cursoId,
}) {
  return Uri.parse(
    '$base/asistencias/por-cedula/pdf?cedula=$cedula&cursoId=$cursoId',
  );
}

  // ===========================================================================
  //  REGISTRO POR QR (sin selección manual de paralelo)
  //  Flujo backend superplataforma:
  //   1) GET /asistentes/buscar/por-cedula/:cedula  → matrículas del estudiante
  //   2) POST /asistencias/registrar { asistenteId } → el back deduce el curso
  //      desde asistente.courseId (auto-asignado vía Bitrix/sync).
  // ===========================================================================

  /// Devuelve las matrículas (asistentes) ACTIVAS de una cédula, ya normalizadas.
  /// Cada item trae al menos: id, courseId, estado, y nombres del estudiante/curso
  /// cuando el backend los incluye.
  Future<List<Map<String, dynamic>>> asistentesPorCedula(String cedula) async {
    final ced = cedula.trim();
    if (ced.isEmpty) return [];
    final uri = Uri.parse('$base/asistentes/buscar/por-cedula/$ced');
    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode == 404) return [];
    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }

    final body = json.decode(res.body);
    final payload =
        (body is Map && body.containsKey('data')) ? body['data'] : body;

    final list = <Map<String, dynamic>>[];
    if (payload is List) {
      for (final e in payload) {
        if (e is Map) list.add(Map<String, dynamic>.from(e));
      }
    } else if (payload is Map) {
      list.add(Map<String, dynamic>.from(payload));
    }
    return list;
  }

  /// Registra la asistencia de un asistente ya resuelto.
  /// [courseId] es opcional: si se omite, el backend usa `asistente.courseId`.
  Future<RegistroAsistenciaResultado> registrar({
    required dynamic asistenteId,
    dynamic courseId,
  }) async {
    final uri = Uri.parse('$base/asistencias/registrar');
    final aid = asistenteId is int
        ? asistenteId
        : int.tryParse(asistenteId.toString());
    if (aid == null) {
      throw Exception('asistenteId inválido');
    }

    final res = await http.post(
      uri,
      headers: await _headers(),
      body: json.encode({
        'asistenteId': aid,
        if (courseId != null) 'courseId': courseId,
      }),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      Map<String, dynamic> body = {};
      try {
        final decoded = json.decode(res.body);
        if (decoded is Map) body = Map<String, dynamic>.from(decoded);
      } catch (_) {}
      return RegistroAsistenciaResultado(
        ok: true,
        deduped: body['deduped'] == true,
        statusCode: res.statusCode,
      );
    }

    return RegistroAsistenciaResultado(
      ok: false,
      statusCode: res.statusCode,
      mensaje: _mensajeError(res.statusCode),
    );
  }

  static String _mensajeError(int code) {
    switch (code) {
      case 400:
        return 'El estudiante no tiene un curso asignado';
      case 401:
        return 'Sesión expirada, vuelve a iniciar sesión';
      case 404:
        return 'Estudiante no encontrado';
      case 409:
        return 'Asistencia ya registrada';
      default:
        return 'Error inesperado ($code)';
    }
  }
}

/// Resultado del registro de asistencia por QR.
class RegistroAsistenciaResultado {
  final bool ok;
  final bool deduped;
  final int statusCode;
  final String? mensaje;

  RegistroAsistenciaResultado({
    required this.ok,
    this.deduped = false,
    required this.statusCode,
    this.mensaje,
  });
}
