import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:nic_pre_u/data/course.dart';
import 'package:nic_pre_u/data/course_with_grades.dart';
import 'package:nic_pre_u/services/auth_service.dart';
import 'package:nic_pre_u/shared/utils/file_downloader.dart';

class CourseService {
  final Map<String, String> headers;
  final AuthService _authService = AuthService();

  // 👇 storage local (igual que en AuthService)
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  CourseService({this.headers = const {}});

  /// Debe terminar en /api (ej: http://10.0.2.2:4000/api)
  String get baseUrl => dotenv.env['API_URL'] ?? '';

  // (sigue disponible si lo usabas)
  Future<List<Course>> fetchCourses() async {
    final uri = Uri.parse('$baseUrl/courses');
    final res = await http.get(uri, headers: headers);
    if (res.statusCode == 200) {
      final body = json.decode(res.body);
      final list = (body as List).cast<Map<String, dynamic>>();
      return list.map(Course.fromMap).toList();
    }
    return [];
  }

  // lib/features/courses/data/course_service.dart
  Future<List<dynamic>> fetchCoursesWithGradesByUsername() async {
    final userData = await _authService.getUser();
    final username = (userData?['cedula'] ?? '').toString();
    if (username.isEmpty) {
      return [];
    }

    final uri = Uri.parse(
      '$baseUrl/moodle/courses/with-gradesv2?username=$username',
    );

    final res = await http.get(uri, headers: headers);

    // ✅ Manejo de 400 "Usuario no encontrado"
    if (res.statusCode == 400) {
      final body = json.decode(res.body);
      if (body is Map && body['message'] == 'Usuario no encontrado') {
        return []; // Devuelve array vacío sin lanzar error
      }
    }

    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode} al obtener cursos con notas');
    }

    final body = json.decode(res.body);

    if (body is List) return body;
    if (body is Map && body['courses'] is List) return body['courses'] as List;

    throw Exception('Formato de respuesta no esperado');
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
    print('Cursos+notas guardados (${courses.length}): ${saved != null}');
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
