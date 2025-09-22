import 'package:flutter/material.dart';
import 'package:nic_pre_u/config/router/app_router.dart';
import 'package:nic_pre_u/services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nic_pre_u/services/my_firebase_messaging_service.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(); 
  //await Firebase.initializeApp();

  // 🔥 Inicializar servicio de notificaciones
  //await MyFirebaseMessagingService().initNotifications();
 Intl.defaultLocale = 'es';                 // opcional pero útil
  await initializeDateFormatting('es');      // 👈 carga datos de 'es'
  final AuthService authService = AuthService();
  final bool isAuthenticated = await authService.hasToken();

  runApp(MyApp(isAuthenticated: isAuthenticated));
}

class MyApp extends StatelessWidget {
  final bool isAuthenticated;

  const MyApp({super.key, required this.isAuthenticated});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: buildRouter(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
    );
  }
}
