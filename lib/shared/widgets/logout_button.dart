import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  static final _storage = const FlutterSecureStorage();

  Future<void> _logout(BuildContext context) async {
    await _storage.deleteAll();
    if (context.mounted) {
      context.go('/login');
    }
  }

  void _showLogoutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 24),

                // Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: DS.error.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    size: 28,
                    color: DS.error,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Cerrar sesion',
                  style: DS.poppins(
                    size: 18,
                    weight: FontWeight.w700,
                    color: DS.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Seguro que deseas cerrar sesion?',
                  style: DS.poppins(
                    size: 14,
                    weight: FontWeight.w400,
                    color: DS.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: NicOutlineButton(
                        text: 'Cancelar',
                        height: 50,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NicGradientButton(
                        text: 'Cerrar sesion',
                        height: 50,
                        onPressed: () async {
                          Navigator.pop(context);
                          await _logout(context);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout_rounded),
      color: Colors.white,
      onPressed: () => _showLogoutSheet(context),
    );
  }
}
