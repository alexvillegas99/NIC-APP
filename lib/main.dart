import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:nic_pre_u/config/router/app_router.dart';
import 'package:nic_pre_u/config/theme/app_theme.dart';
import 'package:nic_pre_u/services/auth_service.dart';
import 'package:nic_pre_u/services/my_firebase_messaging_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bool _devAutoLogin = bool.fromEnvironment('NIC_DEV_AUTO_LOGIN');
const String _devLoginCedula = String.fromEnvironment('NIC_DEV_LOGIN_CEDULA');

void main() async {
  // Mantener la pantalla nativa visible hasta que Flutter esté listo
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await dotenv.load();
  await _runDevAutoLoginIfNeeded();

  Intl.defaultLocale = 'es';
  await initializeDateFormatting('es');

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  final authService = AuthService();
  final isAuthenticated = await authService.hasToken();
  if (isAuthenticated) await initFirebaseMessagingIfSupported();

  final prefs = await SharedPreferences.getInstance();
  final hasCompletedOnboarding = prefs.getBool('onboarding_completed') ?? false;

  // Always re-detect STEAM on every startup from stored user
  bool isSteam = false;
  if (isAuthenticated) {
    final user = await authService.getUser();
    final rol = (user?['rol'] ?? user?['role'] ?? '')
        .toString()
        .toUpperCase()
        .trim();
    final tipo = (user?['tipo'] ?? user?['type'] ?? '')
        .toString()
        .toUpperCase()
        .trim();

    // EST_STEAM = STEAM experience, EST_GENERAL = regular home
    isSteam = rol == 'EST_STEAM' || tipo == 'EST_STEAM';

    // Check any modality field explicitly set to STEAM
    for (final k in [
      'modalidad',
      'modality',
      'programa',
      'program',
      'categoria',
      'category',
      'modo',
      'mode',
    ]) {
      if ((user?[k] ?? '').toString().toUpperCase().trim() == 'STEAM') {
        isSteam = true;
        break;
      }
    }

    await prefs.setBool('is_steam', isSteam);
    debugPrint(
      '🚀 isSteam=$isSteam | rol=$rol | tipo=$tipo | user keys=${user?.keys.toList()}',
    );
  }

  // Si no pasa por SplashScreen, quitar el splash nativo aquí.
  if (isAuthenticated || hasCompletedOnboarding) FlutterNativeSplash.remove();

  runApp(
    NicApp(
      isAuthenticated: isAuthenticated,
      hasCompletedOnboarding: hasCompletedOnboarding,
      isSteam: isSteam,
    ),
  );
}

Future<void> _runDevAutoLoginIfNeeded() async {
  if (!_devAutoLogin || _devLoginCedula.trim().isEmpty) return;

  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_completed', true);

  final apiUrl = dotenv.env['API_URL']?.trim() ?? '';
  if (apiUrl.isEmpty) {
    debugPrint('NIC_DEV_AUTO_LOGIN: API_URL vacío');
    return;
  }

  try {
    final response = await http.post(
      Uri.parse('$apiUrl/auth/login-cedula'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'cedula': _devLoginCedula.trim()}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      debugPrint(
        'NIC_DEV_AUTO_LOGIN: login falló ${response.statusCode} ${response.body}',
      );
      return;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = (data['accessToken'] ?? data['token'] ?? '').toString();
    final user = data['user'] is Map
        ? Map<String, dynamic>.from(data['user'])
        : <String, dynamic>{};

    if (accessToken.isEmpty || user.isEmpty) {
      debugPrint('NIC_DEV_AUTO_LOGIN: token o usuario vacío');
      return;
    }

    user['cedula'] ??= _devLoginCedula.trim();
    user['rol'] = (user['rol'] ?? user['role'] ?? 'EST_GENERAL')
        .toString()
        .toUpperCase();
    user['nombre'] ??= user['fullName'] ?? user['email'];

    const storage = FlutterSecureStorage();
    await storage.write(key: 'accessToken', value: accessToken);
    await storage.write(key: 'user', value: jsonEncode(user));
    await prefs.setBool('is_steam', false);

    debugPrint(
      'NIC_DEV_AUTO_LOGIN: estudiante ${user['nombre']} listo con rol=${user['rol']}',
    );
  } catch (e) {
    debugPrint('NIC_DEV_AUTO_LOGIN: $e');
  }
}

class NicApp extends StatelessWidget {
  final bool isAuthenticated;
  final bool hasCompletedOnboarding;
  final bool isSteam;

  const NicApp({
    super.key,
    required this.isAuthenticated,
    required this.hasCompletedOnboarding,
    this.isSteam = false,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NIC Academy',
      routerConfig: buildRouter(
        hasCompletedOnboarding: hasCompletedOnboarding,
        isAuthenticated: isAuthenticated,
        isSteam: isSteam,
      ),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getAppTheme(),
    );
  }
}
