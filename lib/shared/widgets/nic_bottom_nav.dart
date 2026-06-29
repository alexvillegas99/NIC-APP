import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';

enum NavTab { home, cursos, qr, explorar, perfil }

class NicBottomNav extends StatefulWidget {
  final NavTab current;

  /// Override to force profesor mode without async lookup
  final bool? isProfesor;

  const NicBottomNav({super.key, required this.current, this.isProfesor});

  @override
  State<NicBottomNav> createState() => _NicBottomNavState();
}

class _NicBottomNavState extends State<NicBottomNav> {
  bool _isProfesor = false;

  @override
  void initState() {
    super.initState();
    if (widget.isProfesor != null) {
      _isProfesor = widget.isProfesor!;
    } else {
      _loadRole();
    }
  }

  // Roles que ESCANEAN el QR de estudiantes (registrar asistencia) en vez de
  // mostrar su propio QR: docente/profesor, asesor, maestro y admin.
  static bool _rolEscanea(dynamic rol) {
    final normalized = rol.toString().trim().toUpperCase();
    return normalized == 'PROFESOR' ||
        normalized == 'DOCENTE' ||
        normalized == 'TEACHER' ||
        normalized == 'MAESTRO' ||
        normalized == 'ASESOR' ||
        normalized == 'ADVISOR' ||
        normalized == 'COUNSELOR' ||
        normalized == 'JEFE_VENTAS' ||
        normalized == 'JEFE_VENTAS_STEM' ||
        normalized == 'ADMIN' ||
        normalized == 'ADMINISTRADOR';
  }

  static bool _userEscanea(Map<String, dynamic> user) {
    const directKeys = [
      'rol',
      'role',
      'tipo',
      'type',
      'accountType',
      'perfil',
      'profile',
    ];

    for (final key in directKeys) {
      if (_rolEscanea(user[key])) return true;
    }

    final roles = user['roles'];
    if (roles is Iterable) {
      for (final role in roles) {
        if (_rolEscanea(role)) return true;
        if (role is Map) {
          for (final key in directKeys) {
            if (_rolEscanea(role[key])) return true;
          }
        }
      }
    }

    final nestedUser = user['user'];
    if (nestedUser is Map) {
      for (final key in directKeys) {
        if (_rolEscanea(nestedUser[key])) return true;
      }
    }

    return false;
  }

  Future<void> _loadRole() async {
    const storage = FlutterSecureStorage();
    final userJson = await storage.read(key: 'user');
    if (userJson != null && mounted) {
      try {
        final user = json.decode(userJson) as Map<String, dynamic>;
        setState(() => _isProfesor = _userEscanea(user));
      } catch (_) {}
    }
  }

  void _onTap(BuildContext context, NavTab tab) {
    HapticFeedback.lightImpact();
    switch (tab) {
      case NavTab.home:
        context.go('/home');
      case NavTab.cursos:
        context.go('/home/courses');
      case NavTab.qr:
        context.go(_isProfesor ? '/home/scan' : '/home/myqr');
      case NavTab.explorar:
        context.go('/home/explorar');
      case NavTab.perfil:
        context.go('/home/perfil');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        // Figma: #12141d background, #361e4e border (purple-tinted)
        color: Color(0xFF12141D),
        border: Border(top: BorderSide(color: Color(0xFF361E4E), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Inicio',
                active: widget.current == NavTab.home,
                onTap: () => _onTap(context, NavTab.home),
              ),
              _NavItem(
                icon: Icons.route_rounded,
                label: 'Plan',
                active: widget.current == NavTab.cursos,
                onTap: () => _onTap(context, NavTab.cursos),
              ),
              _QrCenterItem(
                active: widget.current == NavTab.qr,
                isProfesor: _isProfesor,
                onTap: () => _onTap(context, NavTab.qr),
              ),
              _NavItem(
                icon: Icons.search_rounded,
                label: 'Explorar',
                active: widget.current == NavTab.explorar,
                onTap: () => _onTap(context, NavTab.explorar),
              ),
              _NavItem(
                icon: Icons.settings_rounded,
                label: 'Config',
                active: widget.current == NavTab.perfil,
                onTap: () => _onTap(context, NavTab.perfil),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween(
      begin: 1.0,
      end: 0.88,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Active = purple (#672ab5 from Figma), inactive = dim
    const activeColor = Color(0xFF9B7FE8);
    const inactiveColor = Color(0xFF6B6B80);
    final color = widget.active ? activeColor : inactiveColor;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Active indicator dot at top
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: widget.active ? 20 : 0,
                height: 2,
                margin: const EdgeInsets.only(bottom: 5),
                decoration: BoxDecoration(
                  color: activeColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: widget.active
                      ? activeColor.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, size: 20, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 9,
                  fontWeight: widget.active ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrCenterItem extends StatefulWidget {
  final bool active;
  final bool isProfesor;
  final VoidCallback onTap;

  const _QrCenterItem({
    required this.active,
    required this.onTap,
    this.isProfesor = false,
  });

  @override
  State<_QrCenterItem> createState() => _QrCenterItemState();
}

class _QrCenterItemState extends State<_QrCenterItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF9B59F5), Color(0xFF6B1FA8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: DS.purple.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                widget.isProfesor
                    ? Icons.qr_code_scanner_rounded
                    : Icons.qr_code_2_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
