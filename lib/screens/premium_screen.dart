import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';

// ─── Entry point ─────────────────────────────────────────────────────────────

class PremiumScreen {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PremiumSheet(),
    );
  }
}

// ─── Pricing model ────────────────────────────────────────────────────────────

class _Plan {
  final String id;
  final String title;
  final String subtitle;
  final String price;
  final String priceDetail;
  final String badge;
  final bool popular;
  final bool isShared;
  final IconData icon;

  const _Plan({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.priceDetail,
    this.badge = '',
    this.popular = false,
    this.isShared = false,
    required this.icon,
  });
}

const _plans = [
  _Plan(
    id: 'mensual',
    title: 'Mensual',
    subtitle: 'Acceso total',
    price: '\$12',
    priceDetail: 'por mes',
    icon: Icons.calendar_today_rounded,
  ),
  _Plan(
    id: 'semestral',
    title: 'Semestral',
    subtitle: '6 meses de acceso',
    price: '\$8',
    priceDetail: '/mes  ·  \$48 total',
    badge: 'Ahorra 33%',
    icon: Icons.calendar_month_rounded,
  ),
  _Plan(
    id: 'anual',
    title: 'Anual',
    subtitle: '12 meses completo',
    price: '\$6',
    priceDetail: '/mes  ·  \$72 total',
    badge: 'Más popular',
    popular: true,
    icon: Icons.workspace_premium_rounded,
  ),
  _Plan(
    id: 'compartido',
    title: 'Compartido',
    subtitle: 'Para 2 personas',
    price: '\$5',
    priceDetail: '/persona/mes  ·  \$120/año',
    badge: 'Ahorra 58%',
    isShared: true,
    icon: Icons.group_rounded,
  ),
  _Plan(
    id: 'familiar',
    title: 'Familiar',
    subtitle: 'Hasta 5 personas',
    price: '\$4',
    priceDetail: '/persona/mes  ·  \$240/año',
    badge: 'Mejor valor',
    isShared: true,
    icon: Icons.family_restroom_rounded,
  ),
];

// ─── Sheet ────────────────────────────────────────────────────────────────────

class _PremiumSheet extends StatefulWidget {
  const _PremiumSheet();

  @override
  State<_PremiumSheet> createState() => _PremiumSheetState();
}

class _PremiumSheetState extends State<_PremiumSheet> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF12141D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),

            Expanded(
              child: ListView(
                controller: scroll,
                padding: EdgeInsets.zero,
                children: [
                  _buildHero(),
                  _buildFeatures(),
                  _buildPlans(),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Bottom CTA
            if (_selected != null) _buildCTA(context),
          ],
        ),
      ),
    );
  }

  // ─── Hero ──────────────────────────────────────────────────────────────────

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2D1B69), Color(0xFF1A0E4F), Color(0xFF12141D)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // Mascot / Icon
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF9B59F5), Color(0xFF5B1FA8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: DS.purple.withValues(alpha: 0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: DS.purple.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: DS.purple.withValues(alpha: 0.4)),
            ),
            child: Text(
              'NIC PREMIUM',
              style: DS.poppins(
                size: 11,
                weight: FontWeight.w700,
                color: const Color(0xFFB794F4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Desbloquea tu\npotencial académico',
            textAlign: TextAlign.center,
            style: DS.poppins(
              size: 26,
              weight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Accede a todos los cursos, recursos y seguimiento\npersonalizado sin límites.',
            textAlign: TextAlign.center,
            style: DS.poppins(size: 13, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  // ─── Features ─────────────────────────────────────────────────────────────

  Widget _buildFeatures() {
    final features = [
      (Icons.play_circle_rounded, 'Clases ilimitadas', 'Todos los cursos disponibles'),
      (Icons.download_rounded, 'Contenido offline', 'Descarga y aprende sin internet'),
      (Icons.bar_chart_rounded, 'Seguimiento de progreso', 'Reportes detallados de avance'),
      (Icons.support_agent_rounded, 'Soporte prioritario', 'Respuesta en menos de 2 horas'),
      (Icons.psychology_rounded, 'OV ilimitado', 'Sesiones de orientación sin costo adicional'),
      (Icons.group_rounded, 'Comunidad exclusiva', 'Acceso al grupo de estudiantes premium'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Qué incluye Premium?',
            style: DS.poppins(
              size: 16,
              weight: FontWeight.w700,
              color: DS.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: DS.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(f.$1, color: DS.purple, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.$2,
                          style: DS.poppins(
                              size: 13,
                              weight: FontWeight.w600,
                              color: DS.textPrimary)),
                      Text(f.$3,
                          style: DS.poppins(
                              size: 11, color: DS.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF34D399), size: 18),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ─── Plans ────────────────────────────────────────────────────────────────

  Widget _buildPlans() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Elige tu plan',
            style: DS.poppins(
              size: 16,
              weight: FontWeight.w700,
              color: DS.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ..._plans.map((p) => _PlanCard(
                plan: p,
                selected: _selected == p.id,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selected = p.id);
                },
              )),
        ],
      ),
    );
  }

  // ─── CTA ──────────────────────────────────────────────────────────────────

  Widget _buildCTA(BuildContext context) {
    final plan = _plans.firstWhere((p) => p.id == _selected);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      decoration: BoxDecoration(
        color: const Color(0xFF12141D),
        border: Border(
          top: BorderSide(color: DS.divider.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: DS.poppins(
                          size: 14,
                          weight: FontWeight.w700,
                          color: DS.textPrimary),
                    ),
                    Text(
                      '${plan.price} ${plan.priceDetail}',
                      style: DS.poppins(size: 12, color: DS.textSecondary),
                    ),
                  ],
                ),
              ),
              if (plan.isShared) ...[
                _OutlineBtn(
                  label: 'Compartir',
                  icon: Icons.share_rounded,
                  onTap: () => _showCheckout(context, plan, share: true),
                ),
                const SizedBox(width: 8),
              ],
              _PrimaryBtn(
                label: 'Comprar',
                onTap: () => _showCheckout(context, plan, share: false),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text(
              'Ahora no',
              style: DS.poppins(
                  size: 13,
                  color: DS.textSecondary,
                  weight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showCheckout(BuildContext context, _Plan plan, {required bool share}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E2029),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          share ? 'Compartir ${plan.title}' : 'Confirmar compra',
          style: DS.poppins(
              size: 16, weight: FontWeight.w700, color: DS.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plan: ${plan.title}',
                style: DS.poppins(size: 13, color: DS.textSecondary)),
            const SizedBox(height: 4),
            Text('Total a pagar: ${plan.price}',
                style: DS.poppins(
                    size: 18,
                    weight: FontWeight.w800,
                    color: DS.purple)),
            const SizedBox(height: 12),
            Text(
              share
                  ? 'Se generará un enlace para compartir con tu grupo.'
                  : 'Serás redirigido a la pasarela de pago segura.',
              style: DS.poppins(size: 12, color: DS.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: DS.poppins(size: 13, color: DS.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: DS.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    share
                        ? 'Enlace de compartir generado'
                        : 'Redirigiendo a pago...',
                    style: DS.poppins(size: 13, color: Colors.white),
                  ),
                  backgroundColor: DS.purple,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(share ? 'Compartir' : 'Pagar',
                style: DS.poppins(
                    size: 13,
                    weight: FontWeight.w600,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── Plan card ────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final _Plan plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = plan.popular ? DS.purple : const Color(0xFF9191A0);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? DS.purple.withValues(alpha: 0.1)
              : const Color(0xFF1E2029),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? DS.purple
                : plan.popular
                    ? DS.purple.withValues(alpha: 0.4)
                    : const Color(0xFF2A2A3A),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(plan.icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan.title,
                        style: DS.poppins(
                          size: 14,
                          weight: FontWeight.w700,
                          color: DS.textPrimary,
                        ),
                      ),
                      if (plan.badge.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: plan.popular
                                ? DS.purple.withValues(alpha: 0.2)
                                : const Color(0xFF34D399).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            plan.badge,
                            style: DS.poppins(
                              size: 9,
                              weight: FontWeight.w700,
                              color: plan.popular
                                  ? DS.purple
                                  : const Color(0xFF34D399),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    plan.subtitle,
                    style: DS.poppins(size: 11, color: DS.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  plan.price,
                  style: DS.poppins(
                    size: 20,
                    weight: FontWeight.w800,
                    color: selected ? DS.purple : DS.textPrimary,
                  ),
                ),
                Text(
                  plan.priceDetail.split('·').first.trim(),
                  style: DS.poppins(size: 10, color: DS.textSecondary),
                ),
              ],
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? DS.purple : const Color(0xFF3A3A4A),
                  width: 2,
                ),
                color: selected
                    ? DS.purple
                    : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 12)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Buttons ──────────────────────────────────────────────────────────────────

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: DS.nicGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: DS.poppins(
                size: 14, weight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _OutlineBtn(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: DS.purple.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: DS.purple, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: DS.poppins(
                    size: 13,
                    weight: FontWeight.w600,
                    color: DS.purple)),
          ],
        ),
      ),
    );
  }
}
