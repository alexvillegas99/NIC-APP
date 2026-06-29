import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:nic_pre_u/services/asistentes_service.dart';
import 'package:nic_pre_u/services/auth_service.dart';
import 'steam_bottom_nav.dart';
import 'steam_sub_screens.dart';

// ─── Colores STEAM ────────────────────────────────────────────────────────────
class _SC {
  static const bg = Color(0xFF0C0820);
  static const card = Color(0xFF160E2E);
  static const purple = Color(0xFF8B5CF6);
  static const blue = Color(0xFF3B82F6);
  static const green = Color(0xFF10B981);
  static const yellow = Color(0xFFFBBF24);
  static const pink = Color(0xFFEC4899);
  static const orange = Color(0xFFF97316);
  static const cyan = Color(0xFF06B6D4);
}

TextStyle _st(double size, Color color, {FontWeight w = FontWeight.w600}) =>
    TextStyle(
      fontFamily: 'Poppins',
      fontSize: size,
      fontWeight: w,
      color: color,
    );

// ─── Data ─────────────────────────────────────────────────────────────────────
class _SteamData {
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> cursos;
  const _SteamData({required this.user, required this.cursos});
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class SteamHomeScreen extends StatefulWidget {
  const SteamHomeScreen({super.key});
  @override
  State<SteamHomeScreen> createState() => _SteamHomeScreenState();
}

class _SteamHomeScreenState extends State<SteamHomeScreen>
    with TickerProviderStateMixin {
  final _auth = AuthService();
  final _asist = AsistentesService();

  late Future<_SteamData> _future;
  late final AnimationController _floatCtrl;
  late final Animation<double> _float;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;
  late final AnimationController _sidebarCtrl;
  late final Animation<double> _sidebarAnim;

  bool _cursosExpanded = false;
  SteamTab _currentTab = SteamTab.home;

  // Sidebar drag tracking
  double _dragStart = 0;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _float = Tween(
      begin: -8.0,
      end: 8.0,
    ).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _sidebarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _sidebarAnim = CurvedAnimation(
      parent: _sidebarCtrl,
      curve: Curves.easeOutCubic,
    );

    _future = _load();
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _fadeCtrl.dispose();
    _sidebarCtrl.dispose();
    super.dispose();
  }

  void _openSidebar() {
    HapticFeedback.lightImpact();
    _sidebarCtrl.forward();
  }

  void _closeSidebar() {
    _sidebarCtrl.reverse();
  }

  void _openSteamSubScreen(String route, Map<String, dynamic> user) {
    Widget screen;
    switch (route) {
      case 'perfil':
        screen = SteamPerfilScreen(user: user);
        break;
      case 'logros':
        screen = const SteamLogrosScreen();
        break;
      case 'progreso':
        screen = SteamProgresoScreen(user: user);
        break;
      case 'notificaciones':
        screen = const SteamNotificacionesScreen();
        break;
      case 'ayuda':
        screen = const SteamAyudaScreen();
        break;
      default:
        return;
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => screen,
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  Future<_SteamData> _load() async {
    final raw = await _auth.getUser() ?? {};
    final user = (raw['user'] ?? raw) as Map<String, dynamic>;
    final cursos = await _asist.fetchCursosPorCedula();
    return _SteamData(user: user, cursos: cursos);
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _SC.bg,
        body: FutureBuilder<_SteamData>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: _LoadingRocket());
            }
            final data = snap.data ?? _SteamData(user: {}, cursos: []);
            return FadeTransition(
              opacity: _fade,
              child: _buildWithSidebar(data),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWithSidebar(_SteamData data) {
    final sidebarWidth = MediaQuery.of(context).size.width * 0.78;
    return GestureDetector(
      onHorizontalDragStart: (d) => _dragStart = d.globalPosition.dx,
      onHorizontalDragUpdate: (d) {
        final dx = d.globalPosition.dx - _dragStart;
        if (dx > 0 && _sidebarCtrl.value < 1) {
          _sidebarCtrl.value = (dx / sidebarWidth).clamp(0.0, 1.0);
        } else if (dx < 0 && _sidebarCtrl.value > 0) {
          _sidebarCtrl.value = ((sidebarWidth + dx) / sidebarWidth).clamp(
            0.0,
            1.0,
          );
        }
      },
      onHorizontalDragEnd: (d) {
        final vel = d.primaryVelocity ?? 0;
        if (_sidebarCtrl.value > 0.4 || vel > 400) {
          _openSidebar();
        } else {
          _closeSidebar();
        }
      },
      child: Stack(
        children: [
          // ── Main content ──
          Column(
            children: [
              Expanded(child: _tabContent(data)),
              SteamBottomNav(
                current: _currentTab,
                onTap: (t) {
                  HapticFeedback.lightImpact();
                  setState(() => _currentTab = t);
                },
              ),
            ],
          ),

          // ── Dark overlay ──
          AnimatedBuilder(
            animation: _sidebarAnim,
            builder: (_, __) {
              if (_sidebarAnim.value == 0) return const SizedBox.shrink();
              return GestureDetector(
                onTap: _closeSidebar,
                child: Container(
                  color: Colors.black.withValues(
                    alpha: 0.55 * _sidebarAnim.value,
                  ),
                ),
              );
            },
          ),

          // ── Sidebar panel ──
          AnimatedBuilder(
            animation: _sidebarAnim,
            builder: (_, child) => Transform.translate(
              offset: Offset(sidebarWidth * (_sidebarAnim.value - 1), 0),
              child: child,
            ),
            child: _SteamSidebar(
              user: data.user,
              onClose: _closeSidebar,
              onNavigate: (route) async {
                _closeSidebar();
                await Future.delayed(const Duration(milliseconds: 260));
                if (!mounted) return;
                _openSteamSubScreen(route, data.user);
              },
              onLogout: () async {
                _closeSidebar();
                await Future.delayed(const Duration(milliseconds: 300));
                await _auth.logout();
                if (mounted) context.go('/login');
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab router ───────────────────────────────────────────────────────────
  Widget _tabContent(_SteamData data) {
    switch (_currentTab) {
      case SteamTab.home:
        return _buildBody(data);
      case SteamTab.desafios:
        return SteamDesafiosTab(user: data.user);
      case SteamTab.premios:
        return SteamPremiosTab(user: data.user);
      case SteamTab.amigos:
        return const SteamComingSoonTab(
          emoji: '👥',
          title: '¡Amigos próximamente!',
          hint:
              'Podrás retar a tus amigos, ver quién tiene más puntos y estudiar juntos. ¡Va a ser épico! 🔥',
        );
      case SteamTab.qr:
        return SteamQRTab(user: data.user);
    }
  }

  // ─── Body ─────────────────────────────────────────────────────────────────
  Widget _buildBody(_SteamData data) {
    final nombre =
        (data.user['nombre'] ?? data.user['fullName'] ?? 'Explorador')
            .toString()
            .split(' ')
            .first;
    final racha = (data.user['racha'] as num?)?.toInt() ?? 0;
    final puntos = (data.user['puntos'] as num?)?.toInt() ?? 0;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHero(nombre, racha, puntos, data)),
        SliverToBoxAdapter(child: _buildCursos(data.cursos)),
        SliverToBoxAdapter(child: _buildBadges()),
        SliverToBoxAdapter(child: _buildDesafio()),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  // ─── Hero ─────────────────────────────────────────────────────────────────
  Widget _buildHero(String nombre, int racha, int puntos, _SteamData data) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 22,
        right: 22,
        bottom: 28,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2D1B69), Color(0xFF190A40), Color(0xFF0C0820)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Hamburger menu button ──
              GestureDetector(
                onTap: _openSidebar,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.menu_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Greeting
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('¡Hola,', style: _st(20, Colors.white60)),
                    Text(
                      '$nombre! 🌟',
                      style: _st(36, Colors.white, w: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _SC.purple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _SC.purple.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '¡Listo para aprender? 🎮',
                        style: _st(13, Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Rocket mascot — tappable
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  if (data.cursos.isNotEmpty) {
                    final c = data.cursos.first;
                    final nombre = (c['nombre'] ?? 'Curso')
                        .toString()
                        .replaceAll('_', ' ')
                        .replaceAll('-', ' ');
                    _showLessonConfirm(context, nombre, '🚀', _SC.purple);
                  } else {
                    _showNoCourses(context);
                  }
                },
                child: AnimatedBuilder(
                  animation: _float,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, _float.value),
                    child: child,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer glow pulse
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _SC.purple.withValues(alpha: 0.35),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF9333EA), Color(0xFF3B82F6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _SC.purple.withValues(alpha: 0.6),
                              blurRadius: 22,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🚀', style: TextStyle(fontSize: 38)),
                        ),
                      ),
                      // "¡Tócame!" hint
                      Positioned(
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _SC.yellow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '¡Jugar!',
                            style: _st(9, Colors.black, w: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Stat row
          Row(
            children: [
              Expanded(
                child: _StatBubble(
                  emoji: '🔥',
                  value: '$racha',
                  label: 'Racha',
                  color: _SC.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBubble(
                  emoji: '⭐',
                  value: '$puntos',
                  label: 'Puntos',
                  color: _SC.yellow,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBubble(
                  emoji: '📚',
                  value: '${data.cursos.length}',
                  label: 'Cursos',
                  color: _SC.cyan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Badges ───────────────────────────────────────────────────────────────
  static const _badges = [
    {'emoji': '🥇', 'name': 'Primer logro', 'color': 0xFFFBBF24, 'ok': true},
    {'emoji': '🔬', 'name': 'Científico', 'color': 0xFF3B82F6, 'ok': true},
    {'emoji': '🎨', 'name': 'Artista', 'color': 0xFFEC4899, 'ok': true},
    {'emoji': '🧮', 'name': 'Matemático', 'color': 0xFF10B981, 'ok': false},
    {'emoji': '💻', 'name': 'Tecnólogo', 'color': 0xFF8B5CF6, 'ok': false},
    {'emoji': '🌍', 'name': 'Explorador', 'color': 0xFF06B6D4, 'ok': false},
  ];

  Widget _buildBadges() {
    final unlocked = _badges.where((b) => b['ok'] == true).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 16),
          child: Row(
            children: [
              Text('🏅', style: _st(22, Colors.white)),
              const SizedBox(width: 8),
              Text(
                'Mis medallas',
                style: _st(22, Colors.white, w: FontWeight.w900),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _SC.yellow.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _SC.yellow.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '$unlocked/${_badges.length} 🌟',
                  style: _st(13, _SC.yellow, w: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 122,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            physics: const BouncingScrollPhysics(),
            itemCount: _badges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final b = _badges[i];
              return _BadgeItem(
                emoji: b['emoji'] as String,
                name: b['name'] as String,
                color: Color(b['color'] as int),
                unlocked: b['ok'] as bool,
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Cursos ───────────────────────────────────────────────────────────────
  static const _courseColors = [
    _SC.purple,
    _SC.blue,
    _SC.green,
    _SC.orange,
    _SC.pink,
    _SC.cyan,
  ];
  static const _courseEmojis = ['📐', '🔭', '🧪', '🎭', '💡', '🌱'];

  Widget _buildCursos(List<Map<String, dynamic>> cursos) {
    final displayList = _cursosExpanded ? cursos : cursos.take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text('📚', style: _st(22, Colors.white)),
              const SizedBox(width: 8),
              Text(
                'Mis cursos',
                style: _st(22, Colors.white, w: FontWeight.w900),
              ),
              const Spacer(),
              if (cursos.length > 3)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _cursosExpanded = !_cursosExpanded);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _SC.purple.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _SC.purple.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      _cursosExpanded ? '🙈 Ver menos' : '👀 Ver todos',
                      style: _st(12, _SC.purple, w: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (cursos.isEmpty)
            _EmptyCourses()
          else
            ...displayList.asMap().entries.map((e) {
              final i = e.key;
              final c = e.value;
              final color = _courseColors[i % _courseColors.length];
              final emoji = _courseEmojis[i % _courseEmojis.length];
              final nombre = (c['nombre'] ?? 'Curso')
                  .toString()
                  .replaceAll('_', ' ')
                  .replaceAll('-', ' ');
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _CourseTile(
                  nombre: nombre,
                  emoji: emoji,
                  color: color,
                  progress: _calcProgress(c),
                  onTap: () =>
                      _showLessonConfirm(context, nombre, emoji, color),
                ),
              );
            }),
        ],
      ),
    );
  }

  double _calcProgress(Map<String, dynamic> curso) {
    final grades = curso['grades'] as List?;
    if (grades == null || grades.isEmpty) return 0.0;
    double total = 0;
    int count = 0;
    for (final g in grades) {
      if (g is Map) {
        final grade = double.tryParse(
          (g['grade'] ?? g['nota'] ?? '0').toString(),
        );
        if (grade != null) {
          total += grade.clamp(0, 10);
          count++;
        }
      }
    }
    return count > 0 ? (total / count / 10).clamp(0.0, 1.0) : 0.0;
  }

  // ─── Desafío del día ──────────────────────────────────────────────────────
  Widget _buildDesafio() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('🎯', style: _st(22, Colors.white)),
              const SizedBox(width: 8),
              Text(
                'Desafío del día',
                style: _st(22, Colors.white, w: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ChallengeCard(),
        ],
      ),
    );
  }
}

// ─── Sidebar ──────────────────────────────────────────────────────────────────
class _SteamSidebar extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onClose;
  final VoidCallback onLogout;
  final void Function(String route) onNavigate;

  const _SteamSidebar({
    required this.user,
    required this.onClose,
    required this.onLogout,
    required this.onNavigate,
  });

  @override
  State<_SteamSidebar> createState() => _SteamSidebarState();
}

class _SteamSidebarState extends State<_SteamSidebar> {
  @override
  Widget build(BuildContext context) {
    final nombre =
        (widget.user['nombre'] ?? widget.user['fullName'] ?? 'Explorador')
            .toString();
    final email = (widget.user['email'] ?? '').toString();
    final puntos = (widget.user['puntos'] as num?)?.toInt() ?? 0;
    final racha = (widget.user['racha'] as num?)?.toInt() ?? 0;
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBot = MediaQuery.of(context).padding.bottom;
    final width = MediaQuery.of(context).size.width * 0.78;

    return SizedBox(
      width: width,
      height: double.infinity,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A0B3B), Color(0xFF0D0820)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border(
            right: BorderSide(color: Color(0xFF2D1B69), width: 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xAA000000),
              blurRadius: 40,
              spreadRadius: 8,
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Profile header ──
            Container(
              padding: EdgeInsets.fromLTRB(24, safeTop + 20, 24, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2D1B69), Color(0xFF1A0B3B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NIC logo + close button
                  Row(
                    children: [
                      Image.asset(
                        'assets/imagenes/logonic.png',
                        height: 34,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Text(
                          'NIC Academy',
                          style: _st(22, Colors.white, w: FontWeight.w900),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: widget.onClose,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white54,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // User info
                  Text(
                    nombre,
                    style: _st(20, Colors.white, w: FontWeight.w900),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: _st(12, Colors.white38),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Mini stats
                  Row(
                    children: [
                      _SidebarStat(emoji: '⭐', value: '$puntos', label: 'pts'),
                      const SizedBox(width: 12),
                      _SidebarStat(emoji: '🔥', value: '$racha', label: 'días'),
                    ],
                  ),
                ],
              ),
            ),

            // ── Menu items ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _SidebarItem(
                    icon: Icons.person_rounded,
                    color: _SC.purple,
                    label: 'Mi perfil',
                    onTap: () => widget.onNavigate('perfil'),
                  ),
                  _SidebarItem(
                    icon: Icons.emoji_events_rounded,
                    color: _SC.yellow,
                    label: 'Mis logros',
                    onTap: () => widget.onNavigate('logros'),
                  ),
                  _SidebarItem(
                    icon: Icons.bar_chart_rounded,
                    color: _SC.blue,
                    label: 'Mi progreso',
                    onTap: () => widget.onNavigate('progreso'),
                  ),
                  _SidebarItem(
                    icon: Icons.notifications_rounded,
                    color: _SC.orange,
                    label: 'Notificaciones',
                    onTap: () => widget.onNavigate('notificaciones'),
                  ),
                  _SidebarItem(
                    icon: Icons.help_rounded,
                    color: _SC.cyan,
                    label: 'Ayuda',
                    onTap: () => widget.onNavigate('ayuda'),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Divider(color: Colors.white10, thickness: 1),
                  ),
                  _SidebarItem(
                    icon: Icons.logout_rounded,
                    color: _SC.pink,
                    label: 'Cerrar sesión',
                    onTap: widget.onLogout,
                  ),
                ],
              ),
            ),

            // ── Footer ──
            Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, safeBot + 20),
              child: Row(
                children: [
                  Text('NIC Academy', style: _st(11, Colors.white24)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _SC.purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _SC.purple.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'STEAM ✨',
                      style: _st(10, _SC.purple, w: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarStat extends StatelessWidget {
  final String emoji, value, label;
  const _SidebarStat({
    required this.emoji,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: _st(14, Colors.white, w: FontWeight.w900)),
              Text(label, style: _st(10, Colors.white38)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _pressed
              ? widget.color.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.15),
                border: Border.all(color: widget.color.withValues(alpha: 0.3)),
              ),
              child: Icon(widget.icon, color: widget.color, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              widget.label,
              style: _st(16, Colors.white, w: FontWeight.w700),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white24,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Lesson confirm ───────────────────────────────────────────────────────────
void _showLessonConfirm(
  BuildContext ctx,
  String nombre,
  String emoji,
  Color color,
) {
  showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _LessonSheet(nombre: nombre, emoji: emoji, color: color),
  );
}

void _showNoCourses(BuildContext ctx) {
  showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: const BoxDecoration(
        color: Color(0xFF12082A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
        28,
        24,
        28,
        MediaQuery.of(ctx).padding.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('😴', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            '¡Todavía no tienes cursos!',
            style: _st(20, Colors.white, w: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Pídele a tu profe que te inscriba 😊',
            style: _st(15, Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2D1B69),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _SC.purple.withValues(alpha: 0.4)),
              ),
              child: Text(
                '¡Entendido! 👍',
                style: _st(16, Colors.white, w: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LessonSheet extends StatelessWidget {
  final String nombre;
  final String emoji;
  final Color color;
  const _LessonSheet({
    required this.nombre,
    required this.emoji,
    required this.color,
  });

  @override
  Widget build(BuildContext ctx) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF12082A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      padding: EdgeInsets.fromLTRB(
        28,
        20,
        28,
        MediaQuery.of(ctx).padding.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 30),
          // Big emoji
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
              border: Border.all(
                color: color.withValues(alpha: 0.55),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 28,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 52)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '¡Vamos a aprender! 🚀',
            style: _st(24, Colors.white, w: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            nombre,
            style: _st(17, color, w: FontWeight.w700),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            '¿Listo para empezar esta lección?',
            style: _st(15, Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          // BIG start button
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.of(ctx).pop();
              // TODO: navigate to lesson
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.75)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Text(
                    '¡Empezar lección!',
                    style: _st(20, Colors.white, w: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Quizás después 😅', style: _st(15, Colors.white38)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Loading ──────────────────────────────────────────────────────────────────
class _LoadingRocket extends StatefulWidget {
  const _LoadingRocket();
  @override
  State<_LoadingRocket> createState() => _LoadingRocketState();
}

class _LoadingRocketState extends State<_LoadingRocket>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _s;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _s = Tween(
      begin: 0.7,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: AnimatedBuilder(
      animation: _s,
      builder: (_, __) => Transform.scale(
        scale: _s.value,
        child: const Text('🚀', style: TextStyle(fontSize: 60)),
      ),
    ),
  );
}

// ─── Stat bubble ─────────────────────────────────────────────────────────────
class _StatBubble extends StatelessWidget {
  final String emoji, value, label;
  final Color color;
  const _StatBubble({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          Text(value, style: _st(22, Colors.white, w: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: _st(11, color, w: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─── Badge ────────────────────────────────────────────────────────────────────
class _BadgeItem extends StatelessWidget {
  final String emoji, name;
  final Color color;
  final bool unlocked;
  const _BadgeItem({
    required this.emoji,
    required this.name,
    required this.color,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked
                  ? color.withValues(alpha: 0.18)
                  : const Color(0xFF1A1030),
              border: Border.all(
                color: unlocked
                    ? color.withValues(alpha: 0.65)
                    : const Color(0xFF2D2040),
                width: 2.5,
              ),
              boxShadow: unlocked
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                unlocked ? emoji : '🔒',
                style: TextStyle(fontSize: unlocked ? 34 : 26),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            name,
            style: _st(11, unlocked ? Colors.white : Colors.white30),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Course tile ──────────────────────────────────────────────────────────────
class _CourseTile extends StatefulWidget {
  final String nombre, emoji;
  final Color color;
  final double progress;
  final VoidCallback onTap;

  const _CourseTile({
    required this.nombre,
    required this.emoji,
    required this.color,
    required this.progress,
    required this.onTap,
  });
  @override
  State<_CourseTile> createState() => _CourseTileState();
}

class _CourseTileState extends State<_CourseTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _press, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = (widget.progress * 100).round();
    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) {
        _press.reverse();
        widget.onTap();
      },
      onTapCancel: () => _press.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _SC.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Emoji circle
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.18),
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.emoji,
                    style: const TextStyle(fontSize: 34),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.nombre,
                      style: _st(17, Colors.white, w: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Stack(
                      children: [
                        Container(
                          height: 14,
                          decoration: BoxDecoration(
                            color: widget.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: widget.progress.clamp(0.0, 1.0),
                          child: Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: widget.color,
                              borderRadius: BorderRadius.circular(7),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.color.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$pct% completado',
                      style: _st(12, widget.color, w: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Play button — BIG and obvious
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [widget.color, widget.color.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.5),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty courses ────────────────────────────────────────────────────────────
class _EmptyCourses extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _SC.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _SC.purple.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          const Text('😴', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 14),
          Text(
            '¡Todavía no tienes cursos!',
            style: _st(16, Colors.white, w: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Pídele a tu profe que te inscriba 😊',
            style: _st(13, Colors.white54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Challenge card ───────────────────────────────────────────────────────────
class _ChallengeCard extends StatelessWidget {
  static final _rnd = Random();
  static const _challenges = [
    {
      'emoji': '🔢',
      'title': '¡Cuenta hasta 100!',
      'desc': 'Practica tus sumas de hoy',
      'xp': 50,
      'color': 0xFF3B82F6,
    },
    {
      'emoji': '🎨',
      'title': 'Dibuja lo que aprendiste',
      'desc': 'Arte + ciencia = STEAM',
      'xp': 40,
      'color': 0xFFEC4899,
    },
    {
      'emoji': '🌱',
      'title': 'Observa la naturaleza',
      'desc': 'Sal y encuentra 3 plantas',
      'xp': 35,
      'color': 0xFF10B981,
    },
    {
      'emoji': '🔭',
      'title': '¿Cuántas estrellas ves?',
      'desc': 'Mira el cielo esta noche',
      'xp': 60,
      'color': 0xFF8B5CF6,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final ch = _challenges[_rnd.nextInt(_challenges.length)];
    final color = Color(ch['color'] as int);
    final xp = ch['xp'] as int;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.28),
            color.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(ch['emoji'] as String, style: const TextStyle(fontSize: 58)),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ch['title'] as String,
                  style: _st(17, Colors.white, w: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(ch['desc'] as String, style: _st(13, Colors.white60)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.55),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Text(
                        '¡Empezar! →',
                        style: _st(14, Colors.white, w: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '⭐ +$xp XP',
                      style: _st(14, _SC.yellow, w: FontWeight.w800),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB: DESAFÍOS
// ══════════════════════════════════════════════════════════════════════════════
class SteamDesafiosTab extends StatelessWidget {
  final Map<String, dynamic> user;
  const SteamDesafiosTab({super.key, required this.user});

  static const _all = [
    {
      'emoji': '🔢',
      'title': '¡Cuenta hasta 100!',
      'desc': 'Practica tus sumas',
      'xp': 50,
      'color': 0xFF3B82F6,
      'done': true,
    },
    {
      'emoji': '🎨',
      'title': 'Dibuja lo que aprendiste',
      'desc': 'Arte + ciencia = STEAM',
      'xp': 40,
      'color': 0xFFEC4899,
      'done': false,
    },
    {
      'emoji': '🌱',
      'title': 'Observa la naturaleza',
      'desc': 'Sal y encuentra 3 plantas',
      'xp': 35,
      'color': 0xFF10B981,
      'done': false,
    },
    {
      'emoji': '🔭',
      'title': '¿Cuántas estrellas ves?',
      'desc': 'Mira el cielo esta noche',
      'xp': 60,
      'color': 0xFF8B5CF6,
      'done': false,
    },
    {
      'emoji': '💧',
      'title': 'El experimento del agua',
      'desc': '¿Qué flota y qué no?',
      'xp': 45,
      'color': 0xFF06B6D4,
      'done': false,
    },
    {
      'emoji': '🧲',
      'title': 'Juega con imanes',
      'desc': 'Atrae 5 objetos metálicos',
      'xp': 30,
      'color': 0xFFF97316,
      'done': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.fromLTRB(22, top + 20, 22, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF0C0820)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚡ Desafíos',
                  style: _st(32, Colors.white, w: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  '¡Completa retos y gana puntos!',
                  style: _st(15, Colors.white60),
                ),
                const SizedBox(height: 20),
                // Progress strip
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _SC.blue.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 32)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '1 de ${_all.length} completados hoy',
                              style: _st(14, Colors.white, w: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: 1 / _all.length,
                                backgroundColor: Colors.white12,
                                color: _SC.blue,
                                minHeight: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Cards
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((_, i) {
              final ch = _all[i];
              final done = ch['done'] as bool;
              final color = Color(ch['color'] as int);
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _DesafioCard(ch: ch, color: color, done: done),
              );
            }, childCount: _all.length),
          ),
        ),
      ],
    );
  }
}

class _DesafioCard extends StatefulWidget {
  final Map ch;
  final Color color;
  final bool done;
  const _DesafioCard({
    required this.ch,
    required this.color,
    required this.done,
  });
  @override
  State<_DesafioCard> createState() => _DesafioCardState();
}

class _DesafioCardState extends State<_DesafioCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _s;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _s = Tween(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final xp = widget.ch['xp'] as int;
    final color = widget.color;
    final done = widget.done;
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) {
        _c.reverse();
        HapticFeedback.mediumImpact();
      },
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(
        scale: _s,
        child: Opacity(
          opacity: done ? 0.6 : 1.0,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _SC.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: done ? Colors.white12 : color.withValues(alpha: 0.45),
                width: 1.5,
              ),
              boxShadow: done
                  ? null
                  : [
                      BoxShadow(
                        color: color.withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Text(
                  widget.ch['emoji'] as String,
                  style: const TextStyle(fontSize: 44),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.ch['title'] as String,
                        style: _st(16, Colors.white, w: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.ch['desc'] as String,
                        style: _st(12, Colors.white54),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _SC.yellow.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _SC.yellow.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              '⭐ +$xp XP',
                              style: _st(12, _SC.yellow, w: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? Colors.white10 : color,
                    boxShadow: done
                        ? null
                        : [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 12,
                            ),
                          ],
                  ),
                  child: Icon(
                    done ? Icons.check_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB: PREMIOS
// ══════════════════════════════════════════════════════════════════════════════
class SteamPremiosTab extends StatelessWidget {
  final Map<String, dynamic> user;
  const SteamPremiosTab({super.key, required this.user});

  static const _badges = [
    {
      'emoji': '🥇',
      'name': 'Primer logro',
      'color': 0xFFFBBF24,
      'ok': true,
      'pts': 100,
    },
    {
      'emoji': '🔬',
      'name': 'Científico',
      'color': 0xFF3B82F6,
      'ok': true,
      'pts': 150,
    },
    {
      'emoji': '🎨',
      'name': 'Artista',
      'color': 0xFFEC4899,
      'ok': true,
      'pts': 120,
    },
    {
      'emoji': '🧮',
      'name': 'Matemático',
      'color': 0xFF10B981,
      'ok': false,
      'pts': 200,
    },
    {
      'emoji': '💻',
      'name': 'Tecnólogo',
      'color': 0xFF8B5CF6,
      'ok': false,
      'pts': 250,
    },
    {
      'emoji': '🌍',
      'name': 'Explorador',
      'color': 0xFF06B6D4,
      'ok': false,
      'pts': 300,
    },
    {
      'emoji': '🚀',
      'name': 'Astronauta',
      'color': 0xFF9333EA,
      'ok': false,
      'pts': 500,
    },
    {
      'emoji': '🦁',
      'name': 'Líder',
      'color': 0xFFF97316,
      'ok': false,
      'pts': 400,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final puntos = (user['puntos'] as num?)?.toInt() ?? 0;
    final nivel = (puntos / 100).floor() + 1;
    final top = MediaQuery.of(context).padding.top;
    final unlocked = _badges.where((b) => b['ok'] == true).length;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.fromLTRB(22, top + 20, 22, 32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF78350F), Color(0xFF0C0820)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                Text(
                  '🏆 Mis premios',
                  style: _st(32, Colors.white, w: FontWeight.w900),
                ),
                const SizedBox(height: 24),
                // Points display — BIG
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 28,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        _SC.yellow.withValues(alpha: 0.25),
                        Colors.transparent,
                      ],
                      radius: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: _SC.yellow.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text('⭐', style: const TextStyle(fontSize: 52)),
                      const SizedBox(height: 8),
                      Text(
                        '$puntos',
                        style: _st(56, Colors.white, w: FontWeight.w900),
                      ),
                      Text(
                        'PUNTOS TOTALES',
                        style: _st(13, _SC.yellow, w: FontWeight.w800),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _SC.yellow.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '🎖️ Nivel $nivel',
                          style: _st(16, _SC.yellow, w: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 8),
            child: Row(
              children: [
                Text('🏅', style: _st(20, Colors.white)),
                const SizedBox(width: 8),
                Text(
                  'Medallas',
                  style: _st(22, Colors.white, w: FontWeight.w900),
                ),
                const Spacer(),
                Text(
                  '$unlocked / ${_badges.length}',
                  style: _st(14, _SC.yellow, w: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.1,
            ),
            delegate: SliverChildBuilderDelegate((_, i) {
              final b = _badges[i];
              final ok = b['ok'] as bool;
              final color = Color(b['color'] as int);
              final pts = b['pts'] as int;
              return Container(
                decoration: BoxDecoration(
                  color: ok ? color.withValues(alpha: 0.12) : _SC.card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: ok ? color.withValues(alpha: 0.6) : Colors.white10,
                    width: 1.5,
                  ),
                  boxShadow: ok
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 14,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ok ? b['emoji'] as String : '🔒',
                      style: TextStyle(fontSize: ok ? 38 : 30),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      b['name'] as String,
                      style: _st(
                        13,
                        ok ? Colors.white : Colors.white30,
                        w: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ok ? '✅ Obtenida' : '+$pts pts',
                      style: _st(
                        11,
                        ok ? _SC.green : Colors.white30,
                        w: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }, childCount: _badges.length),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB: QR
// ══════════════════════════════════════════════════════════════════════════════
class SteamQRTab extends StatefulWidget {
  final Map<String, dynamic> user;
  const SteamQRTab({super.key, required this.user});
  @override
  State<SteamQRTab> createState() => _SteamQRTabState();
}

class _SteamQRTabState extends State<SteamQRTab> with TickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  late final Animation<double> _glow;
  late final AnimationController _quoteCtrl;
  late final Animation<double> _quoteFade;

  int _quoteIdx = 0;
  static const _quotes = [
    '✨ ¡Cada clase te hace más inteligente!',
    '🚀 ¡Los grandes científicos empezaron como tú!',
    '🔥 ¡Tu racha demuestra que eres increíble!',
    '🌟 ¡Sigue así y llegarás a las estrellas!',
    '💡 ¡La curiosidad es tu superpoder!',
    '🏆 ¡El esfuerzo de hoy es el éxito de mañana!',
  ];

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glow = Tween(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _quoteCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _quoteFade = CurvedAnimation(parent: _quoteCtrl, curve: Curves.easeInOut);
    _quoteCtrl.forward();
    _rotateQuote();
  }

  void _rotateQuote() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) break;
      await _quoteCtrl.reverse();
      if (!mounted) break;
      setState(() => _quoteIdx = (_quoteIdx + 1) % _quotes.length);
      _quoteCtrl.forward();
    }
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _quoteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final nombre =
        (widget.user['nombre'] ?? widget.user['fullName'] ?? 'Explorador')
            .toString()
            .split(' ')
            .first;
    final cedula = (widget.user['cedula'] ?? '').toString();
    final qrData = cedula.isNotEmpty
        ? cedula
        : (widget.user['email'] ?? 'NIC-STEAM').toString();
    final racha = (widget.user['racha'] as num?)?.toInt() ?? 0;
    final puntos = (widget.user['puntos'] as num?)?.toInt() ?? 0;
    final nivel = (puntos / 100).floor() + 1;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Header gradient
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(22, top + 16, 22, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF064E3B),
                  Color(0xFF0A1628),
                  Color(0xFF0C0820),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Mi pase mágico 🪄',
                  style: _st(28, Colors.white, w: FontWeight.w900),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  '¡Muéstraselo a tu profe para entrar! 🎒',
                  style: _st(14, Colors.white54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // ── QR Card ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: AnimatedBuilder(
              animation: _glow,
              builder: (_, child) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: _SC.green.withValues(alpha: _glow.value * 0.55),
                      blurRadius: 28 + _glow.value * 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: child,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: _SC.green.withValues(alpha: 0.7),
                    width: 3,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '¡Hola, $nombre! 👋',
                      style: _st(
                        22,
                        const Color(0xFF111827),
                        w: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (cedula.isNotEmpty)
                      Text(
                        cedula,
                        style: _st(
                          13,
                          const Color(0xFF6B7280),
                          w: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 20),
                    // Real QR
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 1.5,
                        ),
                      ),
                      child: qrData.isNotEmpty
                          ? _QrWidget(data: qrData)
                          : const Icon(
                              Icons.qr_code_2_rounded,
                              size: 180,
                              color: Color(0xFF1A1030),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _SC.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _SC.green.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '✅ Código activo',
                        style: _st(
                          13,
                          const Color(0xFF059669),
                          w: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── KPIs animados ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🏅 Tu progreso',
                  style: _st(20, Colors.white, w: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        emoji: '🔥',
                        value: '$racha',
                        label: 'Días de racha',
                        color: _SC.orange,
                        big: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _KpiCard(
                        emoji: '⭐',
                        value: '$puntos',
                        label: 'Puntos ganados',
                        color: _SC.yellow,
                        big: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        emoji: '🎖️',
                        value: 'Nivel $nivel',
                        label: 'Tu nivel actual',
                        color: _SC.purple,
                        big: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _KpiCard(
                        emoji: '🎯',
                        value: '3',
                        label: 'Desafíos completados',
                        color: _SC.blue,
                        big: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _KpiCard(
                        emoji: '📚',
                        value: '100%',
                        label: 'Asistencia',
                        color: _SC.green,
                        big: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Frase motivacional rotativa ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: FadeTransition(
              opacity: _quoteFade,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _SC.purple.withValues(alpha: 0.25),
                      _SC.blue.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _SC.purple.withValues(alpha: 0.4)),
                ),
                child: Text(
                  _quotes[_quoteIdx],
                  style: _st(15, Colors.white, w: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // ── CTA ───────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
            child: _PulsingCTA(),
          ),
        ],
      ),
    );
  }
}

// Intenta usar qr_flutter, si falla muestra placeholder
class _QrWidget extends StatelessWidget {
  final String data;
  const _QrWidget({required this.data});
  @override
  Widget build(BuildContext context) {
    try {
      return SizedBox(
        width: 200,
        height: 200,
        child: CustomPaint(painter: _QrPainter(data: data)),
      );
    } catch (_) {
      return const Icon(
        Icons.qr_code_2_rounded,
        size: 180,
        color: Color(0xFF1A1030),
      );
    }
  }
}

// Simple QR fallback painter (draws the icon; real qr_flutter is imported below)
class _QrPainter extends CustomPainter {
  final String data;
  const _QrPainter({required this.data});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF111827);
    // Draw placeholder squares to look like QR
    const blocks = 7;
    final cell = size.width / blocks;
    for (int r = 0; r < blocks; r++) {
      for (int c = 0; c < blocks; c++) {
        if (_isFinderPattern(r, c, blocks) || _shouldFill(r, c)) {
          canvas.drawRect(
            Rect.fromLTWH(c * cell + 1, r * cell + 1, cell - 2, cell - 2),
            paint,
          );
        }
      }
    }
  }

  bool _isFinderPattern(int r, int c, int n) =>
      (r < 2 && c < 2) || (r < 2 && c >= n - 2) || (r >= n - 2 && c < 2);
  bool _shouldFill(int r, int c) => (r + c * 3 + r * c) % 3 == 0;
  @override
  bool shouldRepaint(_QrPainter old) => old.data != data;
}

class _KpiCard extends StatelessWidget {
  final String emoji, value, label;
  final Color color;
  final bool big;
  const _KpiCard({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
    required this.big,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: big ? 18 : 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: TextStyle(fontSize: big ? 30 : 24)),
          const SizedBox(height: 6),
          Text(
            value,
            style: _st(big ? 22 : 15, Colors.white, w: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: _st(10, color, w: FontWeight.w700),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _PulsingCTA extends StatefulWidget {
  @override
  State<_PulsingCTA> createState() => _PulsingCTAState();
}

class _PulsingCTAState extends State<_PulsingCTA>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _s;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _s = Tween(
      begin: 1.0,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _s,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _SC.purple.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🚀', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Text(
              '¡Sigue aprendiendo!',
              style: _st(19, Colors.white, w: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB: COMING SOON (Amigos / Más)
// ══════════════════════════════════════════════════════════════════════════════
class SteamComingSoonTab extends StatefulWidget {
  final String emoji, title, hint;
  const SteamComingSoonTab({
    super.key,
    required this.emoji,
    required this.title,
    required this.hint,
  });
  @override
  State<SteamComingSoonTab> createState() => _SteamComingSoonTabState();
}

class _SteamComingSoonTabState extends State<SteamComingSoonTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _s;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _s = Tween(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Column(
      children: [
        SizedBox(height: top + 20),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pulsing emoji
                  ScaleTransition(
                    scale: _s,
                    child: Text(
                      widget.emoji,
                      style: const TextStyle(fontSize: 80),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    widget.title,
                    style: _st(26, Colors.white, w: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _SC.card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: _SC.purple.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      widget.hint,
                      style: _st(15, Colors.white60),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _SC.purple.withValues(alpha: 0.4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Text(
                      '🔔 ¡Avísame cuando llegue!',
                      style: _st(16, Colors.white, w: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
