import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_service.dart';

class EvaluacionesService {
  final String baseUrl = dotenv.env['API_URL'] ?? '';
  final AuthService _auth = AuthService();

  /////////////////////////////////////////////////////////////
  /// 🔹 Verifica si existen evaluaciones activas hoy
  /////////////////////////////////////////////////////////////

  Future<bool> existenEvaluacionesActivas() async {
    if (baseUrl.isEmpty) {
      throw Exception("API_URL no configurado en .env");
    }

    try {
      final response = await http.get(
        Uri.parse("$baseUrl/evaluaciones/activas/hoy"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List && data.isNotEmpty;
      }

      return false;
    } catch (e) {
      print("Error obteniendo evaluaciones activas: $e");
      return false;
    }
  }

  /////////////////////////////////////////////////////////////
  /// 🔹 Obtener estado del estudiante (usa cédula del storage)
  /////////////////////////////////////////////////////////////

  Future<List<dynamic>> obtenerEstadoEstudiante({
    required String evaluacionId,
  }) async {
    if (baseUrl.isEmpty) {
      throw Exception("API_URL no configurado en .env");
    }

    try {
      // 🔹 Obtener usuario del storage
      final res = await _auth.getUser();
      if (res == null) {
        throw Exception('Usuario nulo');
      }

      final user = res['user'] ?? res;
      final String cedula = user['cedula']?.toString() ?? '';

      if (cedula.isEmpty) {
        throw Exception('Cédula no encontrada');
      }

      final uri = Uri.parse(
        "$baseUrl/evaluaciones/estado-estudiante"
        "?evaluacionId=$evaluacionId"
        "&cedula=$cedula",
      );

      final response = await http.get(
        uri,
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("Estado estudiante: ${response.body}");
        return jsonDecode(response.body);
      }

      print("Error estado estudiante: ${response.body}");
      return [];
    } catch (e) {
      print("Error en obtenerEstadoEstudiante: $e");
      return [];
    }
  }

  Future<List<dynamic>> obtenerEvaluacionesActivas() async {
    if (baseUrl.isEmpty) {
      throw Exception("API_URL no configurado");
    }

    try {
      final response = await http.get(
        Uri.parse("$baseUrl/evaluaciones/activas/hoy"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      return [];
    } catch (e) {
      print("Error obteniendo evaluaciones activas: $e");
      return [];
    }
  }

    /////////////////////////////////////////////////////////////
  /// 4️⃣ Enviar evaluación profesor
  /////////////////////////////////////////////////////////////
Future<void> enviarEvaluacionProfesor({
  required String evaluacionId,
  required String profesor,
  required String cursoId,
  required String cursoNombre,
  required int calificacion,
  required String estudianteNombre,
  required String estudianteCedula,
  String? observacion,
}) async {
  final response = await http.post(
    Uri.parse("$baseUrl/evaluaciones/calificaciones"),
    headers: {
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "evaluacionId": evaluacionId,
      "profesorNombre": profesor,
      "cursoId": cursoId,
      "cursoNombre": cursoNombre, // 👈 NUEVO
      "calificacion": calificacion,
      "estudianteNombre": estudianteNombre,
      "estudianteCedula": estudianteCedula,
      "observacion": observacion ?? "",
    }),
  );

  if (response.statusCode != 201 && response.statusCode != 200) {
    throw Exception("Error enviando evaluación");
  }
}




}
