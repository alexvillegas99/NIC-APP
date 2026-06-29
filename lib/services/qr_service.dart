import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class QRService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final String apiUrl = dotenv.env['API_URL'] ?? ''; // 🔹 Cargar URL de la API
  final AuthService _authService =
      AuthService(); // 🔹 Obtener datos del usuario

  // 📌 Generar el QR y guardarlo localmente
  Future<bool> generateAndSaveQR() async {
    try {
      final userData =
          await _authService.getUser(); // 🔹 Obtener usuario actual
      if (userData == null) return false;

      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('$apiUrl/asistentes/generate-qr-app'),
        headers: {
          "Content-Type": "application/json",
          if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
        },
        body: json.encode(userData),
      );
      debugPrint('Response: ${response.body}');

      final Map<String, dynamic> responseData = json.decode(response.body);
      final String? imageBase64 =
          responseData['imageBase64']; // 🔹 Extraer imagen Base64

      if (imageBase64 != null) {
        await _storage.write(
            key: 'qr_image',
            value: imageBase64); // 🔹 Guardar directamente el Base64
        return true;
      }

      debugPrint('Error en la generación del QR: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('Error en generateAndSaveQR: $e');
      return false;
    }
  }

  // 📌 Obtener la imagen QR desde localStorage
  Future<String?> getQRImage() async {
    return await _storage.read(key: 'qr_image'); // 🔹 Retorna el Base64 directo
  }
}
