import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nic_pre_u/services/connectivity_service.dart';
import 'package:nic_pre_u/services/local_cache.dart';
import 'package:nic_pre_u/services/my_firebase_messaging_service.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';

enum LoginMode { classic, credential }

/// Resultado de refrescar la sesión desde el backend.
enum RefreshSesion {
  actualizado, // trajo datos frescos y los guardó
  sinCambio, // no se pudo refrescar (red/no-200) — se queda con lo cacheado
  expirada, // 401: el token fue rechazado (single-session) → re-login
}

bool _isSteamUserMap(Map<String, dynamic> user) {
  // Check explicit STEAM modality field
  const modalityKeys = [
    'modalidad',
    'modality',
    'programa',
    'program',
    'categoria',
    'category',
    'modo',
    'mode',
    'nivel',
    'plan',
    'grupo',
  ];
  for (final k in modalityKeys) {
    if ((user[k] ?? '').toString().toUpperCase().trim() == 'STEAM') return true;
  }
  // Only EST_STEAM role goes to STEAM experience (EST_GENERAL stays in home)
  final rol = (user['rol'] ?? user['role'] ?? '')
      .toString()
      .toUpperCase()
      .trim();
  final tipo = (user['tipo'] ?? user['type'] ?? '')
      .toString()
      .toUpperCase()
      .trim();
  return rol == 'EST_STEAM' || tipo == 'EST_STEAM';
}

class AuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final url = dotenv.env['API_URL'] ?? '';

  // ===================== LOGIN =====================
  Future<void> login(
    String username,
    String password,
    BuildContext context, {
    LoginMode mode = LoginMode.classic,
    String? cedula,
  }) async {
    try {
      late final http.Response response;

      if (mode == LoginMode.credential) {
        // Login por cédula: usa endpoint dedicado
        final loginUrl = Uri.parse('$url/auth/login-cedula');
        response = await http.post(
          loginUrl,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'cedula': cedula ?? username}),
        );
      } else {
        // Login clásico: email + password
        final loginUrl = Uri.parse('$url/auth/login');
        response = await http.post(
          loginUrl,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'email': username, 'password': password}),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        // El backend usa 'token' en /auth/login y 'accessToken' en /auth/login-cedula
        final accessToken =
            (responseData['accessToken'] ?? responseData['token'] ?? '')
                .toString();

        if (accessToken.isEmpty) {
          if (context.mounted) _snack(context, 'Error: no se recibió token');
          return;
        }
        final Map<String, dynamic> user = responseData['user'] is Map
            ? Map<String, dynamic>.from(responseData['user'])
            : <String, dynamic>{};

        debugPrint(
          '🔑 LOGIN user fields: ${user.keys.toList()} | role=${user['role']} | rol=${user['rol']}',
        );

        if (mode == LoginMode.credential) {
          final ced = (cedula ?? username).trim();
          if (ced.isNotEmpty) {
            user['cedula'] ??= ced;
          }

          // Detectar rol
          String? rolDetectado;
          if (ced.isNotEmpty) {
            rolDetectado = await _detectarRolPorCedula(ced, accessToken);
          }

          if (!context.mounted) return;
          String rolFinal;
          if (rolDetectado == null || rolDetectado == 'ambos') {
            final picked = await showRolSelector(context);
            if (picked == null) {
              if (!context.mounted) return;
              _snack(context, 'Debes seleccionar un rol para continuar');
              return;
            }
            rolFinal = picked;
          } else {
            rolFinal = rolDetectado;
          }
          user['rol'] = rolFinal.toUpperCase();

          // Enriquecer datos con info del endpoint tipo-por-cedula
          await _enrichWithTipoPorCedula(user, ced, accessToken);

          if (!context.mounted) return;
          _snack(
            context,
            'Bienvenido, ${user['fullName'] ?? user['nombre'] ?? 'Estudiante'}',
          );
        } else {
          // Classic email login: also try to enrich if user has a cedula
          final ced =
              (user['cedula'] ?? user['document'] ?? user['documento'] ?? '')
                  .toString()
                  .trim();
          if (ced.isNotEmpty) {
            await _enrichWithTipoPorCedula(user, ced, accessToken);
          }
          // If still no rol, try to detect from tipo-por-cedula using cedula
          final rolActual = (user['rol'] ?? user['role'] ?? '')
              .toString()
              .trim();
          if (rolActual.isEmpty && ced.isNotEmpty) {
            final detected = await _detectarRolPorCedula(ced, accessToken);
            if (detected != null && detected != 'ambos') {
              user['rol'] = _mapRole(detected);
            }
          }
        }

        await saveUserData(accessToken, user);
        await initFirebaseMessagingIfSupported();

        if (context.mounted) {
          final isSteam = _isSteamUserMap(user);
          context.go(isSteam ? '/steam' : '/home');
        }
      } else if (response.statusCode == 401) {
        if (context.mounted) {
          _snack(
            context,
            'Credenciales incorrectas. Verifica e intenta de nuevo.',
          );
        }
      } else if (response.statusCode >= 500) {
        if (context.mounted) {
          _snack(context, 'Error del servidor. Intenta en unos minutos.');
        }
      } else {
        if (context.mounted) {
          try {
            final errBody = json.decode(response.body);
            final msg = errBody['message'] ?? 'Error al iniciar sesión';
            _snack(context, msg is List ? msg.join(', ') : msg.toString());
          } catch (_) {
            _snack(context, 'Error al iniciar sesión (${response.statusCode})');
          }
        }
      }
    } catch (e) {
      debugPrint('Login error: $e');
      if (context.mounted) {
        _snack(
          context,
          'No se pudo conectar al servidor. Verifica tu internet.',
        );
      }
    }
  }

  // ===================== LOGIN CON GOOGLE =====================
  Future<void> loginWithGoogle(BuildContext context) async {
    try {
      final googleWebClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim();
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: googleWebClientId?.isNotEmpty == true
            ? googleWebClientId
            : null,
      );
      final account = await googleSignIn.signIn();

      if (account == null) return; // usuario canceló

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        if (context.mounted) {
          _snack(context, 'No se pudo obtener el token de Google');
        }
        return;
      }

      // Enviar token al backend
      final googleUrl = Uri.parse('$url/auth/google');
      final response = await http.post(
        googleUrl,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': idToken}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final accessToken =
            (responseData['accessToken'] ?? responseData['token'] ?? '')
                .toString();
        if (accessToken.isEmpty) {
          if (context.mounted) _snack(context, 'Error: no se recibió token');
          return;
        }
        final Map<String, dynamic> user = responseData['user'] is Map
            ? Map<String, dynamic>.from(responseData['user'])
            : <String, dynamic>{};

        // Si el backend no devuelve rol, detectar o pedir
        final rolActual = (user['rol'] ?? '').toString().trim();
        if (rolActual.isEmpty || rolActual == 'ambos') {
          if (!context.mounted) return;
          final picked = await showRolSelector(context);
          if (picked == null) {
            if (!context.mounted) return;
            _snack(context, 'Debes seleccionar un rol para continuar');
            await googleSignIn.signOut();
            return;
          }
          user['rol'] = picked.toUpperCase();
        }

        await saveUserData(accessToken, user);
        await initFirebaseMessagingIfSupported();

        if (context.mounted) {
          context.go(_isSteamUserMap(user) ? '/steam' : '/home');
        }
      } else {
        if (context.mounted) {
          final body = json.decode(response.body);
          final msg = body['message'] ?? 'Error al iniciar sesión con Google';
          _snack(context, msg.toString());
        }
      }
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      if (context.mounted) {
        _snack(context, 'Error con Google Sign-In. Intenta de nuevo.');
      }
    }
  }

  // ===================== SELECTOR DE ROL (PREMIUM) =====================
  Future<String?> showRolSelector(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: DS.card,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DS.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                // Icono
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: DS.nicGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.people_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '¿Cómo deseas ingresar?',
                  style: DS.poppins(
                    size: 20,
                    weight: FontWeight.w700,
                    color: DS.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Selecciona tu perfil para personalizar tu experiencia',
                  textAlign: TextAlign.center,
                  style: DS.poppins(size: 14, color: DS.textSecondary),
                ),
                const SizedBox(height: 24),

                // Opción Estudiante
                _RolOption(
                  icon: Icons.school_rounded,
                  title: 'Estudiante',
                  subtitle: 'Accede a tus cursos, horarios y calificaciones',
                  color: DS.cyan,
                  onTap: () => Navigator.of(ctx).pop('estudiante'),
                ),
                const SizedBox(height: 12),

                // Opción Representante
                _RolOption(
                  icon: Icons.family_restroom_rounded,
                  title: 'Representante',
                  subtitle: 'Consulta el progreso y asistencia de tu hijo/a',
                  color: DS.orange,
                  onTap: () => Navigator.of(ctx).pop('representante'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===================== ENRIQUECIMIENTO =====================
  Future<void> _enrichWithTipoPorCedula(
    Map<String, dynamic> user,
    String cedula,
    String accessToken,
  ) async {
    try {
      final tipoUri = Uri.parse('$url/usuarios/tipo-por-cedula/$cedula');
      final tipoRes = await http.get(
        tipoUri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (tipoRes.statusCode == 200) {
        final tipoData = json.decode(tipoRes.body);
        debugPrint('🔍 TIPO-POR-CEDULA: $tipoData');
        if (tipoData is Map) {
          user['nombre'] ??= tipoData['data']?['nombre'];
          user['cursos'] ??= tipoData['data']?['cursos'];
          for (final k in [
            'modalidad',
            'modality',
            'tipo',
            'type',
            'programa',
            'program',
            'categoria',
            'category',
            'modo',
            'mode',
          ]) {
            final v = tipoData['data']?[k] ?? tipoData[k];
            if (v != null) user[k] ??= v;
          }
        }
      }
    } catch (_) {}
  }

  // ===================== DETECCIÓN DE ROL =====================
  Future<String?> _detectarRolPorCedula(
    String cedula,
    String accessToken,
  ) async {
    try {
      final uri = Uri.parse('$url/usuarios/tipo-por-cedula/$cedula');
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body is Map) {
          // API returns {"ok":true,"tipo":"estudiante","data":{...}}
          // Check 'tipo' field first (actual field from this endpoint)
          final tipo = (body['tipo'] ?? body['data']?['tipo'] ?? '')
              .toString()
              .toLowerCase()
              .trim();
          if (tipo == 'estudiante' || tipo == 'student') return 'estudiante';
          if (tipo == 'representante' || tipo == 'parent' || tipo == 'padre') {
            return 'representante';
          }
          if (tipo == 'ambos') return 'ambos';

          // Fallback: check 'rol' field
          if (body['rol'] is String) {
            final r = (body['rol'] as String).toLowerCase();
            if (r == 'estudiante' || r == 'representante' || r == 'ambos') {
              return r;
            }
          }
        }
      }

      return null; // Let user pick their role
    } catch (_) {
      return null;
    }
  }

  void _snack(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(msg, style: DS.poppins(size: 14, color: Colors.white)),
        backgroundColor: DS.navy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ===================== STORAGE =====================
  /// Mapea roles del backend a roles de la app
  static String _mapRole(String backendRole) {
    switch (backendRole.toUpperCase()) {
      case 'MAESTRO':
      case 'PROFESOR':
      case 'TEACHER':
        return 'PROFESOR';
      case 'EST_STEAM':
        return 'EST_STEAM'; // STEAM student — own experience
      case 'EST_GENERAL':
      case 'ESTUDIANTE':
      case 'STUDENT':
        return 'EST_GENERAL'; // General student — home experience
      case 'REPRESENTANTE':
      case 'PARENT':
      case 'PADRE':
        return 'REPRESENTANTE';
      case 'ASESOR':
      case 'ADVISOR':
      case 'COUNSELOR':
        return 'ASESOR';
      case 'ADMIN':
      case 'ADMINISTRATOR':
        return 'ADMIN';
      default:
        return backendRole.toUpperCase();
    }
  }

  Future<void> saveUserData(
    String accessToken,
    Map<String, dynamic> user,
  ) async {
    // Normalizar rol
    final backendRole = (user['role'] ?? user['rol'] ?? '').toString();
    if (backendRole.isNotEmpty) {
      user['rol'] = _mapRole(backendRole);
    }
    user['nombre'] ??= user['fullName'] ?? user['email'];

    await _storage.write(key: 'accessToken', value: accessToken);
    await _storage.write(key: 'user', value: json.encode(user));

    // Persist STEAM flag so main.dart reads it instantly at next launch
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_steam', _isSteamUserMap(user));
    debugPrint(
      '💾 STEAM flag saved: ${_isSteamUserMap(user)} | rol=${user['rol']} | tipo=${user['tipo']}',
    );
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
      }
      return false;
    } catch (e) {
      debugPrint('Error en renovación: $e');
      return false;
    }
  }

  /// Refresca los datos del estudiante desde el backend (`GET /auth/me`).
  /// Trae el perfil actualizado (foto, escuela, carreras, teléfono, etc.) y,
  /// muy importante, una **URL firmada fresca del avatar** (la del login caduca
  /// y la foto se ve rota). Mezcla los campos nuevos sobre el usuario cacheado,
  /// conservando los que `/auth/me` no devuelve (p. ej. `tipo`, `cursos`).
  /// Devuelve true si actualizó. Nunca lanza: ante cualquier fallo deja el
  /// usuario cacheado intacto y devuelve false.
  Future<RefreshSesion> refreshUser() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return RefreshSesion.sinCambio;
    try {
      final res = await http
          .get(
            Uri.parse('$url/auth/me'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 401) return RefreshSesion.expirada;
      if (res.statusCode != 200) return RefreshSesion.sinCambio;
      final body = json.decode(res.body);
      final fresh = (body is Map) ? body['user'] : null;
      if (fresh is! Map) return RefreshSesion.sinCambio;
      final current = await getUser() ?? {};
      final merged = {...current, ...Map<String, dynamic>.from(fresh)};
      await saveUserData(token, merged);
      return RefreshSesion.actualizado;
    } catch (e) {
      debugPrint('refreshUser error: $e');
      return RefreshSesion.sinCambio;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'accessToken');
    await _storage.delete(key: 'user');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_steam');
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
  }

  Future<bool> hasToken() async =>
      (await _storage.read(key: 'accessToken')) != null;

  Future<bool> isSteamUser() async {
    final user = await getUser();
    if (user == null) return false;
    return _isSteamUserMap(user);
  }

  // ===================== ASISTENTES =====================
  Future<List<dynamic>> fetchAsistentesPorCedula() async {
    final userData = await getUser();
    final cedula = (userData?['cedula'] ?? '').toString().trim();
    if (cedula.isEmpty) return [];

    final cacheKey = 'ov_asistentes_$cedula';

    Future<List<dynamic>> fromNetwork() async {
      final uri = Uri.parse('$url/asistentes/buscar/por-cedula/$cedula');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = json.decode(res.body);
        final result = body is List ? body : [body];
        await LocalCache.set(cacheKey, result);
        return result;
      }
      return [];
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
}

// ═══════════════════════════════════════════════════════════
//  Widget de opción de rol para el bottom sheet
// ═══════════════════════════════════════════════════════════

class _RolOption extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RolOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_RolOption> createState() => _RolOptionState();
}

class _RolOptionState extends State<_RolOption> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.2),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: widget.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: DS.poppins(
                        size: 16,
                        weight: FontWeight.w700,
                        color: DS.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: DS.poppins(size: 12, color: DS.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: widget.color.withValues(alpha: 0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
