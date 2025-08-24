import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  // 📌 Instancia de `FlutterSecureStorage` para limpiar datos de sesión
  static final _storage = const FlutterSecureStorage();

  // 🔹 Método para cerrar sesión
  Future<void> _logout(BuildContext context) async {
    await _storage.deleteAll(); // 🔄 Eliminar todos los datos guardados
    if (context.mounted) {
      context.go('/login'); // 🔄 Redirigir a la pantalla de inicio de sesión
    }
  }

  // 🔹 Mostrar el modal de confirmación
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // ❌ Cerrar modal sin hacer nada
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // 🔄 Cerrar modal antes de hacer logout
                await _logout(context); // 🔄 Cerrar sesión y redirigir
              },
              child: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout),
      color: const Color.fromARGB(255, 255, 255, 255),
      onPressed: () => _showLogoutDialog(context), // 🔹 Llamar al modal
    );
  }
}
