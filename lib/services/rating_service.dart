import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nic_pre_u/services/auth_service.dart';

class RatingService {
  final String baseUrl = dotenv.env['API_URL'] ?? '';
  final AuthService _authService = AuthService();

  Future<void> enviarCalificacion({
    required String usuario,
    required int calificacion,
    String? observacion,
  }) async {
    final token = await _authService.getToken();
    final uri = Uri.parse('$baseUrl/ratings');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'advisorName': usuario,
        'rating': calificacion,
        'observation': observacion ?? '',
      }),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Error al enviar calificación');
    }
  }
}
