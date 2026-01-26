import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RatingService {
  final String baseUrl = dotenv.env['API_URL'] ?? ''; // 🔹 Cargar URL de la API

  Future<void> enviarCalificacion({
    required String usuario,
    required int calificacion,
    String? observacion,
  }) async {
    final uri = Uri.parse('$baseUrl/ratings');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'usuario': usuario,
        'calificacion': calificacion,
        'observacion': observacion,
      }),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Error al enviar calificación');
    }
  }
}
