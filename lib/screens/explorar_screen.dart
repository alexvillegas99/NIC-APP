import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';
import 'package:nic_pre_u/shared/widgets/nic_bottom_nav.dart';

class ExplorarScreen extends StatelessWidget {
  const ExplorarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: DS.bg,
        body: Column(
          children: [
            const _ExploreHeader(),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: const [
                  _AvailableLabel(),
                  SizedBox(height: 14),
                  _ExploreResourceCard(
                    title: 'Simuladores de admisión',
                    subtitle: 'Practica con bancos reales y revisa tu avance.',
                    icon: Icons.science_rounded,
                    accent: DS.blue,
                    route: '/home/simuladores',
                  ),
                  SizedBox(height: 14),
                  _ExploreResourceCard(
                    title: 'Orientación vocacional',
                    subtitle: 'Completa tu ruta de 7 tests y mira tu reporte.',
                    icon: Icons.psychology_alt_rounded,
                    accent: DS.orange,
                    route: '/home/orientacion',
                  ),
                  SizedBox(height: 18),
                  _AdminNote(),
                ],
              ),
            ),
            const NicBottomNav(current: NavTab.explorar),
          ],
        ),
      ),
    );
  }
}

class _ExploreHeader extends StatelessWidget {
  const _ExploreHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 22,
        left: 20,
        right: 20,
        bottom: 22,
      ),
      decoration: BoxDecoration(
        color: DS.bg,
        border: Border(
          bottom: BorderSide(color: DS.divider.withValues(alpha: 0.45)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explorar',
            style: DS.poppins(
              size: 32,
              weight: FontWeight.w900,
              color: DS.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Recursos activos para avanzar en NIC.',
            style: DS.poppins(size: 13, color: DS.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _AvailableLabel extends StatelessWidget {
  const _AvailableLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Disponible ahora',
      style: DS.poppins(
        size: 16,
        weight: FontWeight.w800,
        color: DS.textPrimary,
      ),
    );
  }
}

class _ExploreResourceCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String route;

  const _ExploreResourceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.route,
  });

  @override
  State<_ExploreResourceCard> createState() => _ExploreResourceCardState();
}

class _ExploreResourceCardState extends State<_ExploreResourceCard> {
  bool _pressed = false;

  void _open() {
    HapticFeedback.lightImpact();
    context.push(widget.route);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _open,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: DS.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: widget.accent.withValues(alpha: 0.32)),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: widget.accent.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(widget.icon, color: widget.accent, size: 28),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: DS.poppins(
                        size: 16,
                        weight: FontWeight.w800,
                        color: DS.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.subtitle,
                      style: DS.poppins(
                        size: 12.5,
                        height: 1.35,
                        color: DS.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                color: widget.accent.withValues(alpha: 0.9),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminNote extends StatelessWidget {
  const _AdminNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DS.cardSoft.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DS.divider.withValues(alpha: 0.7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_clock_rounded,
            color: DS.textSecondary.withValues(alpha: 0.9),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Más recursos aparecerán automáticamente cuando estén activos desde administración.',
              style: DS.poppins(
                size: 12.5,
                height: 1.35,
                color: DS.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
