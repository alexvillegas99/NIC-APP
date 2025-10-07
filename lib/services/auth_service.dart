import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum LoginMode { classic, credential }

class AuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final url = dotenv.env['API_URL'] ?? ''; // BASE URL

  // ===================== LOGIN =====================
  Future<void> login(
    String username,
    String password,
    BuildContext context, {
    LoginMode mode = LoginMode.classic,
    String? cedula,
  }) async {
    final loginUrl = Uri.parse('$url/auth/login');

    try {
      final response = await http.post(
        loginUrl,
        body: {'email': username, 'password': password},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('usuario $responseData');
        final accessToken = responseData['accessToken'];
        final Map<String, dynamic> user =
            (responseData['user'] ?? <String, dynamic>{}) as Map<String, dynamic>;

        // Si es login por credencial (cédula), detectar o pedir rol
        if (mode == LoginMode.credential) {
          final ced = (cedula ?? '').trim();
          if (ced.isNotEmpty) {
            user['cedula'] ??= ced; // por si tu backend no la devuelve
          }

          // 1) Intentar detectar automáticamente
          String? rolDetectado;
          if (ced.isNotEmpty && accessToken != null) {
            rolDetectado = await _detectarRolPorCedula(ced, accessToken);
          }

          // 2) Si no hay certeza → pedir al usuario
          String rolFinal;
          if (rolDetectado == null || rolDetectado == 'ambos') {
            final picked = await _elegirRolBottomSheet(context);
            if (picked == null) {
              _snack(context, 'Debes seleccionar un rol para continuar');
              return;
            }
            rolFinal = picked;
          } else {
            rolFinal = rolDetectado;
          }
          print('rolFinal $rolFinal');
          user['rol'] = rolFinal.toUpperCase();; // persistimos el rol elegido/detectado
          _snack(context, 'Ingresaste como ${_prettyRol(rolFinal)}');
        }

        // Guardar credenciales & usuario
        await saveUserData(accessToken, user);

        // Redirigir al Home (tu misma pantalla, con rol distinto en la UI)
        if (context.mounted) {
          context.go('/home');
        }
      } else {
        if (context.mounted) {
          _snack(context, 'Error en el inicio de sesión');
        }
      }
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'Error de conexión');
      }
    }
  }

  // ===================== DETECCIÓN DE ROL =====================
  // Debe devolver "estudiante" | "representante" | "ambos" | null
  Future<String?> _detectarRolPorCedula(String cedula, String accessToken) async {
    try {
      // Opción A: endpoint dedicado (recomendado)
      final uri = Uri.parse('$url/usuarios/tipo-por-cedula/$cedula');
      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer $accessToken',
      });

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body is Map && body['rol'] is String) {
          final r = (body['rol'] as String).toLowerCase();
          if (r == 'estudiante' || r == 'representante' || r == 'ambos') {
            return r;
          }
        }
      }

      // Opción B (fallback): si ya tienes asistentes por cédula, inferir
      final asistentes = await fetchAsistentesPorCedula();
      if (asistentes.isNotEmpty) {
        // si quieres, aquí podrías verificar también si existe registro de estudiante para devolver "ambos"
        return 'representante';
      }

      return null;
    } catch (_) {
      return null;
    }
  }

Future<String?> _elegirRolBottomSheet(BuildContext context) async {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: const Color(0xFF111320), // mismo que card
    isDismissible: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Selecciona tu tipo de acceso',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEDEDED), // textPrimary
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Si eres padre/madre o tutor, elige Representante.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF9EA3B0), // textSecondary
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.school_outlined, color: Color(0xFF9EA3B0)),
                title: const Text('Estudiante',
                    style: TextStyle(color: Color(0xFFEDEDED))),
                onTap: () => Navigator.of(context).pop('estudiante'),
              ),
              ListTile(
                leading: const Icon(Icons.family_restroom_outlined, color: Color(0xFF9EA3B0)),
                title: const Text('Representante',
                    style: TextStyle(color: Color(0xFFEDEDED))),
                onTap: () => Navigator.of(context).pop('representante'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

  String _prettyRol(String rol) {
    switch (rol) {
      case 'estudiante':
        return 'ESTUDIANTE';
      case 'representante':
        return 'REPRESENTANTE';
      case 'profesor':
        return 'PROFESOR';
      default:
        return rol;
    }
  }

  void _snack(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ===================== STORAGE =====================
  Future<void> saveUserData(String accessToken, Map<String, dynamic> user) async {
    await _storage.write(key: 'accessToken', value: accessToken);
    await _storage.write(key: 'user', value: json.encode(user));

    // logs opcionales
    final savedToken = await _storage.read(key: 'accessToken');
    final savedUser = await _storage.read(key: 'user');
    print('Token guardado: $savedToken');
    print('Usuario guardado: $savedUser');
  }

  Future<String?> getToken() async => _storage.read(key: 'accessToken');

  Future<Map<String, dynamic>?> getUser() async {
    final userString = await _storage.read(key: 'user');
    if (userString != null) return json.decode(userString);
    return null;
  }

  Future<bool> renewToken() async {
    final token = await getToken();
    if (token == null) return false;

    final renewUrl = Uri.parse('$url/auth/refresh-token');
    try {
      final response = await http.get(
        renewUrl,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final newToken = responseData['token'];
        final user = responseData['user'];
        await saveUserData(newToken, user);
        return true;
      } else {
        print('Error al renovar token: ${response.statusCode}');
        print('Respuesta: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error en renovación: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'accessToken');
    await _storage.delete(key: 'user');
    print('Datos de autenticación eliminados');
  }

  Future<bool> hasToken() async =>
      (await _storage.read(key: 'accessToken')) != null;

  // ===================== EXISTENTE: asistentes por cédula =====================
  Future<List<dynamic>> fetchAsistentesPorCedula() async {
    final userData = await getUser();
    final cedula = userData?['cedula'] ?? '';
    if (cedula.isEmpty) return [];

    final uri = Uri.parse('$url/asistentes/buscar/por-cedula/$cedula');
    final res = await http.get(uri);

    print('Asistentes encontrados (status): ${res.statusCode}');
    print('Asistentes encontrados (body): ${res.body}');

    if (res.statusCode == 200 || res.statusCode == 201) {
      final body = json.decode(res.body);
      print('Asistentes decodificados: $body');

      if (body is List) {
        return body;
      } else if (body is Map<String, dynamic>) {
        return [body];
      }
    }
    return [];
  }
}
