import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:nic_pre_u/services/auth_service.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';
import 'package:nic_pre_u/shared/widgets/nic_bottom_nav.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _auth = AuthService();
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  // Usuario: se muestra el cacheado al instante y se refresca desde el backend.
  late Future<Map<String, dynamic>?> _userFuture;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _userFuture = _auth.getUser();
    _refrescar();
  }

  /// Trae datos frescos del backend (foto/perfil) y repinta si cambió algo.
  Future<void> _refrescar() async {
    final res = await _auth.refreshUser();
    if (!mounted) return;
    if (res == RefreshSesion.expirada) {
      await _auth.logout();
      if (mounted) context.go('/login');
      return;
    }
    if (res == RefreshSesion.actualizado) {
      setState(() {
        _userFuture = _auth.getUser();
      });
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _logout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DS.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DS.red.withValues(alpha: 0.12),
                ),
                child: const Icon(Icons.logout_rounded, color: DS.red, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                'Cerrar sesión',
                style: DS.poppins(
                  size: 18,
                  weight: FontWeight.w700,
                  color: DS.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '¿Seguro que deseas cerrar sesión?',
                style: DS.poppins(size: 14, color: DS.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: DS.divider),
                        foregroundColor: DS.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancelar',
                        style: DS.poppins(
                            size: 14,
                            weight: FontWeight.w600,
                            color: DS.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DS.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        await const FlutterSecureStorage().deleteAll();
                        if (context.mounted) context.go('/login');
                      },
                      child: Text(
                        'Cerrar sesión',
                        style: DS.poppins(
                            size: 14,
                            weight: FontWeight.w600,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: DS.bg,
        body: Column(
          children: [
            Expanded(
              child: FadeTransition(
                opacity: _fade,
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: _userFuture,
                  builder: (context, snap) {
                    final user = snap.data ?? {};
                    final name =
                        (user['nombre'] ?? user['email'] ?? 'Usuario') as String;
                    final rol = (user['rol'] ?? '').toString();
                    final activo = user['estado'] ?? true;
                    final avatarUrl = (user['avatarUrl'] ?? '').toString();
                    final parts = name.trim().split(RegExp(r'\s+'));
                    final initials = parts.length >= 2
                        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
                        : name
                            .substring(0, name.length.clamp(0, 2))
                            .toUpperCase();

                    return RefreshIndicator(
                      color: DS.purple,
                      backgroundColor: DS.card,
                      onRefresh: _refrescar,
                      child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 16,
                        left: 20,
                        right: 20,
                        bottom: 24,
                      ),
                      child: Column(
                        children: [
                          // Avatar — foto del estudiante si la tiene, si no iniciales
                          _Avatar(avatarUrl: avatarUrl, initials: initials),
                          const SizedBox(height: 14),
                          Text(
                            name,
                            style: DS.poppins(
                              size: 20,
                              weight: FontWeight.w700,
                              color: DS.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: DS.purple.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  rol.isEmpty
                                      ? 'Usuario'
                                      : '${rol[0].toUpperCase()}${rol.substring(1).toLowerCase()}',
                                  style: DS.poppins(
                                    size: 12,
                                    weight: FontWeight.w600,
                                    color: DS.purple,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: activo == true ? DS.green : DS.red,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                activo == true ? 'Activo' : 'Inactivo',
                                style: DS.poppins(
                                  size: 12,
                                  color: activo == true ? DS.green : DS.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Options
                          _buildSection('Cuenta', [
                            _OptionTile(
                              icon: Icons.person_outline_rounded,
                              label: 'Mi perfil',
                              onTap: () {},
                            ),
                            _OptionTile(
                              icon: Icons.schedule_rounded,
                              label: 'Mis horarios',
                              onTap: () =>
                                  context.push('/home/horarios-estudiantes'),
                            ),
                            _OptionTile(
                              icon: Icons.description_outlined,
                              label: 'Asistencia',
                              onTap: () => context.push('/home/asistencia'),
                            ),
                            _OptionTile(
                              icon: Icons.grade_outlined,
                              label: 'Notas',
                              onTap: () => context.push('/home/notas'),
                            ),
                          ]),
                          const SizedBox(height: 16),
                          _buildSection('Sesión', [
                            _OptionTile(
                              icon: Icons.logout_rounded,
                              label: 'Cerrar sesión',
                              color: DS.red,
                              onTap: () => _logout(context),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    );
                  },
                ),
              ),
            ),
            const NicBottomNav(current: NavTab.perfil),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: DS.poppins(
            size: 13,
            weight: FontWeight.w600,
            color: DS.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: DS.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DS.divider),
          ),
          child: Column(children: tiles),
        ),
      ],
    );
  }
}

// Avatar del perfil: muestra la foto del estudiante (avatarUrl) si existe,
// con fallback al círculo degradado con iniciales mientras carga o si no hay foto.
class _Avatar extends StatelessWidget {
  final String avatarUrl;
  final String initials;

  const _Avatar({required this.avatarUrl, required this.initials});

  Widget _placeholder() => Container(
        width: 88,
        height: 88,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF9B59F5), Color(0xFF5030CF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: DS.poppins(
              size: 28, weight: FontWeight.w700, color: Colors.white),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (avatarUrl.isEmpty) return _placeholder();
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: DS.purple.withValues(alpha: 0.4), width: 2),
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          width: 88,
          height: 88,
          fit: BoxFit.cover,
          placeholder: (_, __) => _placeholder(),
          errorWidget: (_, __, ___) => _placeholder(),
        ),
      ),
    );
  }
}

class _OptionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? DS.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.7 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(widget.icon, color: color, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.label,
                  style: DS.poppins(
                    size: 14,
                    weight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
              if (widget.color == null)
                const Icon(Icons.chevron_right_rounded,
                    color: DS.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
