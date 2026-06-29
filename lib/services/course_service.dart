import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:nic_pre_u/data/course.dart';
import 'package:nic_pre_u/services/auth_service.dart';
import 'package:nic_pre_u/services/connectivity_service.dart';
import 'package:nic_pre_u/services/local_cache.dart';
import 'package:nic_pre_u/shared/utils/file_downloader.dart';

class CourseService {
  final Map<String, String> headers;
  final AuthService _authService = AuthService();

  // 👇 storage local (igual que en AuthService)
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  CourseService({this.headers = const {}});

  String get baseUrl => dotenv.env['API_URL'] ?? '';

  Future<Map<String, String>> _authHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      ...headers,
    };
  }

  // (sigue disponible si lo usabas)
  Future<List<Course>> fetchCourses() async {
    final uri = Uri.parse('$baseUrl/courses');
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode == 200) {
      final body = json.decode(res.body);
      final list = (body as List).cast<Map<String, dynamic>>();
      return list.map(Course.fromMap).toList();
    }
    return [];
  }

    /// 🔹 Obtener cursos activos (para escaneo de asistencia)
Future<List<Map<String, dynamic>>> getActiveCourses() async {
  final String baseUrl = dotenv.env['API_URL'] ?? '';
  if (baseUrl.isEmpty) {
    throw Exception('API_URL no configurada');
  }

  final uri = Uri.parse(
    baseUrl.endsWith('/')
        ? '${baseUrl}cursos?estado=active'
        : '$baseUrl/cursos?estado=active',
  );

  final res = await http.get(uri, headers: await _authHeaders()).timeout(const Duration(seconds: 10));

  if (res.statusCode != 200) {
    throw Exception('Error ${res.statusCode} al obtener cursos activos');
  }

  final body = jsonDecode(res.body);
  if (body is! List) return [];

  return List<Map<String, dynamic>>.from(body);
}

  // lib/features/courses/data/course_service.dart
  Future<List<dynamic>> fetchCoursesWithGradesByUsername() async {
    final userData = await _authService.getUser();
    final username = (userData?['cedula'] ?? '').toString();
    if (username.isEmpty) return [];

    final cacheKey = 'moodle_courses_$username';

    Future<List<dynamic>> fromNetwork() async {
      final uri = Uri.parse(
        '$baseUrl/moodle/courses/with-gradesv2?username=$username',
      );
      final res = await http.get(uri, headers: await _authHeaders())
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 400) {
        final body = json.decode(res.body);
        if (body is Map && body['message'] == 'Usuario no encontrado') {
          return [];
        }
      }
      if (res.statusCode != 200) {
        throw Exception('Error ${res.statusCode} al obtener cursos con notas');
      }
      final body = json.decode(res.body);
      List<dynamic> result;
      if (body is List) {
        result = body;
      } else if (body is Map && body['courses'] is List) {
        result = body['courses'] as List;
      } else {
        throw Exception('Formato de respuesta no esperado');
      }
      await LocalCache.set(cacheKey, result);
      return result;
    }

    final online = await ConnectivityService.instance.check();
    if (online) {
      try {
        return await fromNetwork();
      } catch (_) {
        final cached = await LocalCache.get(cacheKey);
        return cached is List ? cached : [];
      }
    } else {
      final cached = await LocalCache.get(cacheKey);
      return cached is List ? cached : [];
    }
  }

  String _coursesKey(String username) => 'courses_with_grades_$username';

  // --- 🔹 Guardar lista de cursos+notas ---
  Future<void> saveCoursesWithGrades(
    List<dynamic> courses, {
    String? username,
  }) async {
    final userData = await _authService.getUser();
    final cedula = username ?? (userData?['cedula'] ?? '').toString();
    if (cedula.isEmpty) return;

    await _storage.write(key: _coursesKey(cedula), value: json.encode(courses));

    // Debug opcional
    final saved = await _storage.read(key: _coursesKey(cedula));
    debugPrint('Cursos+notas guardados (${courses.length}): ${saved != null}');
  }

  // --- 🔹 Leer lista guardada (para "Ver todos", etc.) ---
  Future<List<dynamic>> getSavedCoursesWithGrades({String? username}) async {
    final userData = await _authService.getUser();
    final cedula = username ?? (userData?['cedula'] ?? '').toString();
    if (cedula.isEmpty) return [];

    final raw = await _storage.read(key: _coursesKey(cedula));
    if (raw == null) return [];
    try {
      final decoded = json.decode(raw);
      return decoded is List ? decoded : [];
    } catch (_) {
      return [];
    }
  }

  // --- 🔹 Buscar un curso por id dentro de lo guardado (para pantalla de notas) ---
  Future<Map<String, dynamic>?> getSavedCourseById(
    int id, {
    String? username,
  }) async {
    final list = await getSavedCoursesWithGrades(username: username);
    for (final item in list) {
      final m = (item as Map).cast<String, dynamic>();
      if (m['id'] == id) return m;
    }
    return null;
  }

  // --- 🔹 Borrar cache si lo necesitas ---
  Future<void> clearSavedCoursesWithGrades({String? username}) async {
    final userData = await _authService.getUser();
    final cedula = username ?? (userData?['cedula'] ?? '').toString();
    if (cedula.isEmpty) return;
    await _storage.delete(key: _coursesKey(cedula));
  }

  Uri buildNotasPdfUri(String cedula) {
    return Uri.parse('$baseUrl/moodle/notas/pdf?cedula=$cedula');
  }

  Future<void> descargarNotasPdfDelUsuario({
    ProgressCallback? onProgress,
  }) async {
    final user = await _authService.getUser();
    final cedula = (user?['cedula'] ?? '').toString();
    if (cedula.isEmpty) {
      throw Exception('No hay cédula en la sesión');
    }

    final uri = buildNotasPdfUri(cedula);

    // Si usas token:
    String? token;
    try {
      token = await _authService.getToken();
    } catch (_) {}

    final hdrs = <String, String>{
      'Accept': 'application/pdf',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      ...headers,
    };

    await FileDownloader.downloadAndOpen(
      uri,
      filename: 'reporte_notas_$cedula.pdf',
      headers: hdrs,
      onProgress: onProgress,
    );
  }



}
