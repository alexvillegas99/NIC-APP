import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:nic_pre_u/services/auth_service.dart';
import 'package:nic_pre_u/shared/utils/debug_log.dart';

class AsistentesService {
  final AuthService _auth = AuthService();

  /// Debe terminar en /api (ej: http://10.0.2.2:4000/api)
  String get baseUrl => dotenv.env['API_URL'] ?? '';

  // ========= Helpers de casteo/normalización =========

  /// Convierte cualquier `Map` (de claves dinámicas) a `Map<String,dynamic>`
  Map<String, dynamic> asStringKeyedMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) {
      return v.map((k, val) => MapEntry(k?.toString() ?? '', val));
    }
    return <String, dynamic>{};
  }

  /// Si el backend a veces devuelve `[{..}]` y otras `{..}`, esto lo normaliza a `List<Map<String,dynamic>>`
  List<Map<String, dynamic>> asListOfStringKeyedMaps(dynamic v) {
    if (v is List) {
      return v
          .where((e) => e is Map)
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (v is Map) {
      return [Map<String, dynamic>.from(v as Map)];
    }
    return <Map<String, dynamic>>[];
  }

  // ========= Headers con token =========

  /// Construye headers con Bearer token si existe
  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Exponer headers (útil para pasarlos al FileDownloader)
  Future<Map<String, String>> publicAuthHeaders() => _authHeaders();

  // ========= Moodle: cursos con notas (V2) =========

  /// GET /moodle/courses/with-gradesv2?username=<cedula>
  /// Devuelve siempre List<dynamic> (vacía si 400 "Usuario no encontrado")
  Future<List<dynamic>> obtenerNotasV2(String username) async {
    final uri = Uri.parse('$baseUrl/moodle/courses/with-gradesv2?username=$username');
    final res = await http.get(uri, headers: await _authHeaders());

    // Manejo de 400 "Usuario no encontrado" como lista vacía
    if (res.statusCode == 400) {
      final body = json.decode(res.body);
      if (body is Map && body['message'] == 'Usuario no encontrado') {
        return <dynamic>[];
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = json.decode(res.body);
      return (data is List) ? data : <dynamic>[];
    }
    throw Exception('Error ${res.statusCode} al obtener cursos con notas');
  }
Uri buildOvPdfUri(String cedula) {
  final base = baseUrl.replaceFirst('localhost', '10.0.2.2');
  return Uri.parse('$base/asistentes/ov/$cedula');
}

  // ========= Asistentes (con Orientación Vocacional) =========

  /// GET /asistentes/por-cedula?cedula=<cedula>
  /// Devuelve SIEMPRE List<Map<String,dynamic>>
Future<List<Map<String, dynamic>>> fetchAsistentesPorCedula({String? cedula}) async {
  final user = await _auth.getUser();
  final ced = (cedula ?? (user?['cedula'] ?? '')).toString().trim();
  debugLog('fetchAsistentesPorCedula.cedula', ced);

  if (ced.isEmpty) {
    debugLog('fetchAsistentesPorCedula', 'Cedula vacía → []');
    return [];
  }

  final uri = Uri.parse('$baseUrl/asistentes/buscar/por-cedula/$ced');
  final headers = await _authHeaders();

  debugLog('HTTP GET', {
    'url': uri.toString(),
    'headers': headers,
  });

  http.Response res;
  try {
    res = await http.get(uri, headers: headers);
  } catch (e) {
    debugLog('HTTP ERROR (network)', e.toString());
    rethrow;
  }

  debugLog('HTTP status', res.statusCode);
  debugLog('HTTP raw body', res.body);

  if (res.statusCode == 200) {
    dynamic body;
    try {
      body = json.decode(res.body);
      debugLog('decoded.body.runtimeType', body.runtimeType.toString());
    } catch (e) {
      debugLog('JSON decode ERROR', e.toString());
      throw Exception('Respuesta no es JSON válido');
    }

    final dynamic payload =
        (body is Map && body.containsKey('data')) ? body['data'] : body;
    debugLog('payload.runtimeType', payload.runtimeType.toString());

    final normalized = asListOfStringKeyedMaps(payload);
    debugLog('normalized.length', normalized.length);

    if (normalized.isNotEmpty) {
      debugLog('normalized[0].keys', normalized.first.keys.toList());
    }
    return normalized;
  }

  if (res.statusCode == 404) {
    debugLog('HTTP 404', 'Sin registros para $ced → []');
    return [];
  }

  debugLog('HTTP ERROR (status)', res.statusCode);
  throw Exception('HTTP ${res.statusCode}: no se pudo obtener asistente');
}
  /// Azúcar sintáctico: devuelve el primer asistente (o null)
  Future<Map<String, dynamic>?> fetchAsistenteActual({String? cedula}) async {
    final lista = await fetchAsistentesPorCedula(cedula: cedula);
    return lista.isEmpty ? null : lista.first;
  }

  // ========= URLs para PDF (para usar con tu FileDownloader) =========

  /// PDF de Orientación Vocacional
  Uri buildPdfUriOV(String cedula) {
    return Uri.parse('$baseUrl/reports/ov/por-cedula/pdf?cedula=$cedula');
  }

  /// PDF de Notas Moodle (si lo expones igual desde el back)
  Uri buildPdfUriNotas(String cedula) {
    return Uri.parse('$baseUrl/reports/notas/por-cedula/pdf?cedula=$cedula');
  }

  // ========= Utilidad opcional =========

  /// Cédula de la sesión (puede ser útil en algunas pantallas)
  Future<String?> cedulaSesion() async {
    final user = await _auth.getUser();
    final c = (user?['cedula'] ?? '').toString().trim();
    return c.isEmpty ? null : c;
  }
}
