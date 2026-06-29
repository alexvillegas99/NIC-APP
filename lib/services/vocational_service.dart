import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:nic_pre_u/services/auth_service.dart';

class VocationalService {
  final AuthService _auth = AuthService();

  String get baseUrl => dotenv.env['API_URL'] ?? '';

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  dynamic _decode(http.Response res) {
    final body = res.body.isEmpty ? null : json.decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is Map && body.containsKey('data')) return body['data'];
      return body;
    }
    final message = body is Map
        ? (body['message'] ?? body['error'] ?? body).toString()
        : res.body;
    throw Exception('HTTP ${res.statusCode}: $message');
  }

  Future<Map<String, dynamic>> estado() async {
    final uri = Uri.parse('$baseUrl/vocational/estado');
    final res = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 18));
    final data = _decode(res);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> modulo(String slug) async {
    final uri = Uri.parse('$baseUrl/vocational/modulo/$slug');
    final res = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 18));
    final data = _decode(res);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> submitModulo({
    required String slug,
    required List<dynamic> answers,
  }) async {
    final uri = Uri.parse('$baseUrl/vocational/modulo/$slug/submit');
    final res = await http
        .post(
          uri,
          headers: await _headers(),
          body: json.encode({'answers': answers}),
        )
        .timeout(const Duration(seconds: 25));
    final data = _decode(res);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> calcularDiagnostico() async {
    final uri = Uri.parse('$baseUrl/vocational/diagnostico/calcular');
    final res = await http
        .post(uri, headers: await _headers())
        .timeout(const Duration(seconds: 25));
    final data = _decode(res);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> diagnostico() async {
    final uri = Uri.parse('$baseUrl/vocational/diagnostico');
    final res = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 18));
    final data = _decode(res);
    return Map<String, dynamic>.from(data as Map);
  }
}
