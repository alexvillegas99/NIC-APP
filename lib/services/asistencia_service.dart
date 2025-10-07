// lib/services/asistencia_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  AsistenciaResumen({
    required this.totalRegistros,
    required this.ultimaFecha,
    required this.diasConAsistencia,
    required this.porcentajeAsistencia,
    required this.totalAsistenciasAcumuladas,
  });

  factory AsistenciaResumen.fromJson(Map<String, dynamic> j) => AsistenciaResumen(
        totalRegistros: (j['totalRegistros'] as num? ?? 0).toInt(),
        ultimaFecha: j['ultimaFecha']?.toString(),
        diasConAsistencia: (j['diasConAsistencia'] as num? ?? 0).toInt(),
        porcentajeAsistencia: (j['porcentajeAsistencia'] as num? ?? 0).toInt(),
        totalAsistenciasAcumuladas:
            (j['totalAsistenciasAcumuladas'] as num? ?? 0).toInt(),
      );
}

class AsistenciaRegistro {
  final String fecha;            // YYYY-MM-DD
  final List<String> horas;      // ['08:00:00', '12:00:00', ...]

  AsistenciaRegistro({
    required this.fecha,
    required this.horas,
  });

  factory AsistenciaRegistro.fromJson(Map<String, dynamic> j) => AsistenciaRegistro(
        fecha: j['fecha']?.toString() ?? '',
        horas: ((j['horas'] as List?) ?? const [])
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList(),
      );
}

class AsistenciaReporte {
  final String cedula;
  final String? asistenteId;
  final String? asistenteNombre;
  final AsistenciaCurso curso;
  final AsistenciaResumen resumen;
  final List<AsistenciaRegistro> registros;

  AsistenciaReporte({
    required this.cedula,
    this.asistenteId,
    this.asistenteNombre,
    required this.curso,
    required this.resumen,
    required this.registros,
  });

  factory AsistenciaReporte.fromJson(Map<String, dynamic> j) => AsistenciaReporte(
        cedula: j['cedula']?.toString() ?? '',
        asistenteId: j['asistente']?['id']?.toString(),
        asistenteNombre: j['asistente']?['nombre']?.toString(),
        curso: AsistenciaCurso.fromJson((j['curso'] ?? {}) as Map<String, dynamic>),
        resumen: AsistenciaResumen.fromJson((j['resumen'] ?? {}) as Map<String, dynamic>),
        registros: ((j['registros'] as List?) ?? const [])
            .map((e) => AsistenciaRegistro.fromJson((e ?? {}) as Map<String, dynamic>))
            .toList(),
      );
}

class AsistenciaService {
  /// Debe ser algo como http://localhost:4000/api (sin slash final adicional)
  final String base = dotenv.env['API_URL'] ?? '';

  Future<AsistenciaReporte> getPorCedula(String cedula) async {
    final uri = Uri.parse('$base/asistencias/por-cedula?cedula=$cedula');
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }
    final data = json.decode(res.body) as Map<String, dynamic>;
    return AsistenciaReporte.fromJson(data);
  }

  /// Si el PDF lo genera el backend (recomendado)
  Uri buildPdfUri(String cedula) =>
      Uri.parse('$base/asistencias/por-cedula/pdf?cedula=$cedula');


}
