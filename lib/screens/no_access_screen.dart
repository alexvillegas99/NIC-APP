import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nic_pre_u/screens/premium_screen.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';

class NoAccessScreen extends StatelessWidget {
  final String section;
  const NoAccessScreen({super.key, this.section = 'esta sección'});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: DS.bg,
        body: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 14,
                left: 8,
                right: 20,
                bottom: 14,
              ),
              decoration: BoxDecoration(
                color: DS.bg,
                border: Border(
                    bottom:
                        BorderSide(color: DS.divider.withValues(alpha: 0.5))),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    'Acceso restringido',
                    style: DS.poppins(
                      size: 17,
                      weight: FontWeight.w700,
                      color: DS.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Lock icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2D1B69), Color(0xFF3B1F7A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: DS.purple.withValues(alpha: 0.4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: DS.purple.withValues(alpha: 0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.lock_rounded,
                          color: Color(0xFFA78BFA), size: 44),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Contenido Premium',
                      style: DS.poppins(
                        size: 22,
                        weight: FontWeight.w800,
                        color: DS.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No tienes acceso a $section.\nActiva tu membresía NIC Premium para desbloquear todo el contenido.',
                      style: DS.poppins(
                        size: 14,
                        color: DS.textSecondary,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),
                    // Premium CTA
                    GestureDetector(
                      onTap: () => PremiumScreen.show(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF9B7FE8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: DS.purple.withValues(alpha: 0.45),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.auto_awesome_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Activar NIC Premium',
                              style: DS.poppins(
                                size: 15,
                                weight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Text(
                        'Volver',
                        style: DS.poppins(
                          size: 14,
                          weight: FontWeight.w500,
                          color: DS.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
