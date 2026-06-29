import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import 'package:nic_pre_u/services/auth_service.dart';
import 'package:nic_pre_u/services/asistentes_service.dart';
import 'package:nic_pre_u/services/connectivity_service.dart';
import 'package:nic_pre_u/services/last_activity_service.dart';
import 'package:nic_pre_u/services/simulador_service.dart';
import 'package:nic_pre_u/screens/simuladores/simulador_run_screen.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';
import 'package:nic_pre_u/shared/widgets/campanas_carousel.dart';
import 'package:nic_pre_u/shared/widgets/glass_card.dart';
import 'package:nic_pre_u/shared/widgets/nic_bottom_nav.dart';
import 'package:nic_pre_u/screens/course_detail_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final AsistentesService _asistentesService = AsistentesService();

  late PageController _pageController;
  Timer? _timer;
  String _userRole = '';
  Key _reloadKey = UniqueKey();
  bool _isOnline = true;
  StreamSubscription<bool>? _connectSub;

  final List<String> cardImages = const [];

  // Animation controller for micro-interactions
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoScroll();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadRole();

    // Conectividad real
    ConnectivityService.instance.startMonitoring();
    _isOnline = ConnectivityService.instance.isOnline;
    _connectSub = ConnectivityService.instance.onChanged.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
  }

  Future<void> _loadRole() async {
    // Pinta al instante con lo cacheado…
    final user = await _authService.getUser();
    if (mounted) {
      setState(() => _userRole = _readRole(user));
    }
    // …y refresca desde el backend (foto/perfil actualizados).
    final res = await _authService.refreshUser();
    if (!mounted) return;
    if (res == RefreshSesion.expirada) {
      // Sesión reemplazada (login en otro lado) → re-login limpio.
      await _authService.logout();
      if (mounted) context.go('/login');
      return;
    }
    if (res == RefreshSesion.actualizado) {
      final fresh = await _authService.getUser();
      setState(() => _userRole = _readRole(fresh));
    }
  }

  /// Lee el rol del usuario de forma robusta: el backend puede mandarlo en
  /// `rol` o en `role` (EST_GENERAL, EST_STEAM, MAESTRO, ASESOR, ...).
  static String _readRole(Map<String, dynamic>? user) {
    if (user == null) return '';
    final r = (user['rol'] ?? user['role'] ?? '').toString().trim();
    return r.toUpperCase();
  }

  /// ¿El usuario es estudiante? (cualquier variante de rol o tipo).
  static bool _isStudentRole(String role, [String tipo = '']) {
    final r = role.toUpperCase();
    return r == 'ESTUDIANTE' ||
        r == 'EST_GENERAL' ||
        r == 'EST_STEAM' ||
        tipo.toLowerCase() == 'estudiante';
  }

  void _startAutoScroll() {
    _timer?.cancel();
    if (cardImages.isEmpty) return;

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients) {
        final nextPage =
            ((_pageController.page ?? 0).toInt() + 1) % cardImages.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connectSub?.cancel();
    _pageController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    _timer?.cancel();
    _pageController.dispose();
    _pageController = PageController();
    _startAutoScroll();

    setState(() {
      _reloadKey = UniqueKey();
    });

    // Re-trigger fade-in
    _fadeCtrl.reset();
    _fadeCtrl.forward();
  }

  // ===== OV Helpers (robust) =====

  Map<String, dynamic> _extractOVFromAsistente(Map<String, dynamic> asistente) {
    final ov = asistente['orientacionVocacional'];
    return ov is Map<String, dynamic> ? ov : <String, dynamic>{};
  }

  Future<String> _getUserRole() async {
    final userData = await _authService.getUser();
    return _readRole(userData);
  }

  String? _readIso(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is DateTime) return v.toUtc().toIso8601String();
    if (v is Map) {
      final d = v[r'$date'];
      if (d is String) return d;
      if (d is int) {
        return DateTime.fromMillisecondsSinceEpoch(
          d,
          isUtc: true,
        ).toUtc().toIso8601String();
      }
    }
    return null;
  }

  String? _etapaKey(String etapaRaw) {
    switch (etapaRaw) {
      case 'PRIMERA':
        return 'primera';
      case 'SEGUNDA':
        return 'segunda';
      case 'TERCERA':
        return 'tercera';
      case 'CUARTA':
        return 'cuarta';
    }
    return null;
  }

  String _formatOVDateLike(dynamic isoLike) {
    final iso = _readIso(isoLike);
    if (iso == null || iso.isEmpty) return '--';
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('EEE d MMM, HH:mm', 'es').format(d);
    } catch (_) {
      return '--';
    }
  }

  String _etapaLabel(String raw) {
    switch (raw) {
      case 'PRIMERA':
        return 'Primera cita';
      case 'SEGUNDA':
        return 'Segunda cita';
      case 'TERCERA':
        return 'Tercera cita';
      case 'CUARTA':
        return 'Cuarta cita';
      default:
        return 'Sin asignar';
    }
  }

  Color _etapaColor(String raw) {
    switch (raw) {
      case 'PRIMERA':
        return const Color(0xFF60A5FA);
      case 'SEGUNDA':
        return const Color(0xFFF59E0B);
      case 'TERCERA':
        return const Color(0xFFA78BFA);
      case 'CUARTA':
        return const Color(0xFF34D399);
      default:
        return DS.textSecondary;
    }
  }

  // ===== Logout =====

  void _showLogoutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DS.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DS.error.withValues(alpha: 0.08),
                  ),
                  child: Icon(Icons.logout_rounded, size: 28, color: DS.error),
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
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: DS.textSecondary.withValues(alpha: 0.3),
                          ),
                          foregroundColor: DS.textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancelar',
                          style: DS.poppins(size: 14, weight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DS.error,
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
                            color: Colors.white,
                          ),
                        ),
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

  // ===== Build =====

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: DS.bg,
        body: KeyedSubtree(
          key: _reloadKey,
          child: Column(
            children: [
              // -- Header --
              _buildHeader(),

              // -- Scrollable body --
              Expanded(
                child: RefreshIndicator(
                  color: DS.purple,
                  backgroundColor: DS.card,
                  onRefresh: _refreshAll,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 20, bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Offline banner
                          if (!_isOnline) _OfflineBanner(),

                          // Profesor promo card
                          if (_userRole == 'PROFESOR') _buildProfesorCard(),

                          // Alert zone (estudiantes only)
                          if (_isStudentRole(_userRole))
                            _AlertZoneWidget(
                              authService: _authService,
                              asistentesService: _asistentesService,
                            ),

                          // Action menu + courses + campaigns
                          _buildMainContent(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // -- Bottom Nav --
              const NicBottomNav(current: NavTab.home),
            ],
          ),
        ),
      ),
    );
  }

  // ============================
  // Header redesigned
  // ============================

  static Color _roleColor(String rol) {
    switch (rol.toUpperCase()) {
      case 'ESTUDIANTE':
      case 'EST_GENERAL':
      case 'EST_STEAM':
        return const Color(0xFF34D399);
      case 'PROFESOR':
      case 'MAESTRO':
        return const Color(0xFF9B7FE8);
      case 'ASESOR':
        return const Color(0xFF60A5FA);
      case 'REPRESENTANTE':
        return const Color(0xFFFBBF24);
      case 'ADMIN':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF34D399);
    }
  }

  static String _roleLetter(String rol) {
    switch (rol.toUpperCase()) {
      case 'ESTUDIANTE':
      case 'EST_GENERAL':
      case 'EST_STEAM':
        return 'E';
      case 'PROFESOR':
      case 'MAESTRO':
        return 'P';
      case 'ASESOR':
        return 'A';
      case 'REPRESENTANTE':
        return 'R';
      case 'ADMIN':
        return 'ADM';
      default:
        return 'E';
    }
  }

  Widget _buildHeader() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _authService.getUser(),
      builder: (context, snap) {
        final user = snap.data ?? {};
        final name =
            (user['nombre'] ?? user['fullName'] ?? user['email'] ?? 'Usuario')
                .toString();
        final firstName = name.split(' ').first;
        final rol = _readRole(user);
        final roleColor = _roleColor(rol);
        final roleLetter = _roleLetter(rol);
        final isActive = _isOnline; // red network connectivity

        return Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20,
            right: 16,
            bottom: 14,
          ),
          decoration: BoxDecoration(
            color: DS.bg,
            border: Border(
              bottom: BorderSide(color: DS.divider.withValues(alpha: 0.5)),
            ),
          ),
          child: Row(
            children: [
              // Logo
              Image.asset(
                'assets/imagenes/logonic.png',
                width: 38,
                height: 30,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              // Greeting
              Expanded(
                child: Text(
                  'Hola, $firstName!',
                  style: DS.poppins(
                    size: 17,
                    weight: FontWeight.w700,
                    color: DS.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Calendar shortcut — left of the E
              _HeaderActionBtn(
                onTap: () => context.push('/home/horarios-estudiantes'),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 6),
              // Role circle pill with status dot overlay — centre
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: roleColor.withValues(alpha: 0.15),
                      border: Border.all(
                        color: roleColor.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      roleLetter,
                      style: DS.poppins(
                        size: roleLetter.length > 1 ? 9 : 13,
                        weight: FontWeight.w700,
                        color: roleColor,
                      ),
                    ),
                  ),
                  // Status dot: top-right of the circle
                  Positioned(
                    top: -2,
                    right: -2,
                    child: _StatusDot(isOnline: isActive),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              // Logout
              _HeaderActionBtn(
                onTap: () => _showLogoutSheet(context),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // (user info card removed — info is in header + alert zone)

  // ignore: unused_element
  Widget _buildUserInfoCard() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _authService.getUser(),
      builder: (context, snapUser) {
        final user = snapUser.data ?? {};
        final name = (user['nombre'] ?? user['email'] ?? 'Usuario') as String;
        final rol = (user['rol'] ?? '').toString();
        final rolUpper = rol.toUpperCase();
        final roleColor = _roleColor(rolUpper);
        final roleLetter = _roleLetter(rolUpper);
        final isActive = _isOnline;

        final parts = name.trim().split(RegExp(r'\s+'));
        final initials = parts.length >= 2
            ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
            : name.substring(0, name.length.clamp(0, 2)).toUpperCase();

        // Build next class widget only for ESTUDIANTE
        Widget nextClassSection = const SizedBox.shrink();
        if (rolUpper == 'ESTUDIANTE') {
          nextClassSection = FutureBuilder<List<Map<String, dynamic>>>(
            future: _asistentesService.fetchCursosPorCedula(),
            builder: (context, snapCursos) {
              if (snapCursos.connectionState != ConnectionState.done) {
                return const SizedBox.shrink();
              }
              final cursos = snapCursos.data ?? [];
              if (cursos.isEmpty) return const SizedBox.shrink();

              final hoy = _diaActual();
              Map<String, dynamic>? proximaCurso;
              Map<String, dynamic>? proximaHora;
              Duration? tiempoRestante;
              final ahora = TimeOfDay.now();
              final ahoraMin = ahora.hour * 60 + ahora.minute;

              for (final curso in cursos) {
                final horario = curso['horario'];
                if (horario is! List) continue;
                for (final h in horario) {
                  if (h is! Map) continue;
                  if ((h['Dia'] ?? '').toString() != hoy) continue;
                  final parts2 = (h['Hora inicio'] ?? '').toString().split(':');
                  if (parts2.length < 2) continue;
                  final claseMin =
                      (int.tryParse(parts2[0]) ?? 0) * 60 +
                      (int.tryParse(parts2[1]) ?? 0);
                  final diff = claseMin - ahoraMin;
                  if (diff >= 0 && diff <= 300) {
                    if (tiempoRestante == null ||
                        diff < tiempoRestante.inMinutes) {
                      tiempoRestante = Duration(minutes: diff);
                      proximaCurso = Map<String, dynamic>.from(curso);
                      proximaHora = Map<String, dynamic>.from(h);
                    }
                  }
                }
              }

              if (proximaCurso == null) return const SizedBox.shrink();

              final nombre = (proximaCurso['nombre'] ?? 'Clase')
                  .toString()
                  .replaceAll('_', ' ')
                  .replaceAll('-', ' ');
              final hora = (proximaHora!['Hora inicio'] ?? '').toString();
              final mins = tiempoRestante!.inMinutes;

              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: mins <= 60
                    ? _NextClassCountdown(
                        courseName: nombre,
                        hora: hora,
                        minutesLeft: mins,
                      )
                    : _NextClassInfo(courseName: nombre, hora: hora, hoy: hoy),
              );
            },
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: NicCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: DS.nicGradient,
                        boxShadow: [
                          BoxShadow(
                            color: DS.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: DS.poppins(
                          size: 18,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: DS.poppins(
                              size: 15,
                              weight: FontWeight.w700,
                              color: DS.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Role circle (same as header)
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: roleColor.withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: roleColor.withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  roleLetter,
                                  style: DS.poppins(
                                    size: roleLetter.length > 1 ? 8 : 11,
                                    weight: FontWeight.w700,
                                    color: roleColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Pulsing dot + status text
                              _PulsingDot(isActive: isActive),
                              const SizedBox(width: 6),
                              Text(
                                isActive ? 'Activo' : 'Inactivo',
                                style: DS.poppins(
                                  size: 12,
                                  weight: FontWeight.w500,
                                  color: isActive
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                nextClassSection,
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================
  // Profesor promo card
  // ============================

  Widget _buildProfesorCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2D1B69), Color(0xFF1C1C2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: DS.purple.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: DS.purple.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: DS.purple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: DS.purple.withValues(alpha: 0.4)),
              ),
              child: const Icon(
                Icons.class_rounded,
                color: DS.purple,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contenido de clases',
                    style: DS.poppins(
                      size: 15,
                      weight: FontWeight.w700,
                      color: DS.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gestiona tu material y alumnos',
                    style: DS.poppins(size: 12, color: DS.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => context.go('/home/explorar'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: DS.nicGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Ver detalles',
                  style: DS.poppins(
                    size: 12,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _diaActual() {
    switch (DateTime.now().weekday) {
      case DateTime.monday:
        return 'Lunes';
      case DateTime.tuesday:
        return 'Martes';
      case DateTime.wednesday:
        return 'Miércoles';
      case DateTime.thursday:
        return 'Jueves';
      case DateTime.friday:
        return 'Viernes';
      case DateTime.saturday:
        return 'Sábado';
      case DateTime.sunday:
        return 'Domingo';
      default:
        return 'Lunes';
    }
  }

  // (OV status card replaced by alert zone)

  // ignore: unused_element
  Widget _buildOVStatusCard() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _authService.getUser(),
      builder: (context, snapUser) {
        if (snapUser.connectionState != ConnectionState.done) {
          return const SizedBox();
        }

        final user = snapUser.data ?? {};
        debugPrint('user en OV: $user');
        final rol = (user['rol'] ?? '').toString().trim();
        debugPrint('rol en OV: $rol');

        if (rol != 'estudiante') return const SizedBox.shrink();

        return FutureBuilder<List<dynamic>>(
          future: _authService.fetchAsistentesPorCedula(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return _ovCard(
                etapa: 'Cargando...',
                fecha: '--',
                color: DS.textSecondary,
              );
            }
            if (snap.hasError) {
              debugPrint('fetchAsistentesPorCedula error: ${snap.error}');
              return _ovCard(
                etapa: 'Sin asignar',
                fecha: '--',
                color: DS.textSecondary,
              );
            }

            final lista = snap.data ?? [];
            if (lista.isEmpty || lista.first is! Map<String, dynamic>) {
              return _ovCard(
                etapa: 'Sin asignar',
                fecha: '--',
                color: DS.textSecondary,
              );
            }

            final asistente = lista.first as Map<String, dynamic>;
            final ov = _extractOVFromAsistente(asistente);

            final etapaRaw = (ov['etapaActual'] ?? 'SIN_CITA')
                .toString()
                .trim()
                .toUpperCase();

            dynamic fechaLike = ov['siguienteCitaISO'];
            if (fechaLike == null) {
              final key = _etapaKey(etapaRaw);
              if (key != null && ov[key] is Map) {
                fechaLike = (ov[key] as Map)['fechaISO'];
              }
            }

            final etapaBonita = _etapaLabel(etapaRaw);
            final fechaBonita = _formatOVDateLike(fechaLike);
            final color = _etapaColor(etapaRaw);

            return _ovCard(
              etapa: etapaBonita,
              fecha: fechaBonita,
              color: color,
            );
          },
        );
      },
    );
  }

  Widget _ovCard({
    required String etapa,
    required String fecha,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: NicCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            // Icon circle with soft color
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
              ),
              child: Icon(Icons.event_rounded, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Orientacion Vocacional',
                    style: DS.poppins(
                      size: 15,
                      weight: FontWeight.w700,
                      color: DS.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Etapa chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: color.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          etapa,
                          style: DS.poppins(
                            size: 11,
                            weight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: DS.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          fecha,
                          style: DS.poppins(
                            size: 12,
                            weight: FontWeight.w400,
                            color: DS.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================
  // Main Content (Menu + Courses + Campaigns)
  // ============================

  Widget _buildMainContent() {
    return FutureBuilder<String>(
      future: _getUserRole(),
      builder: (context, snapshot) {
        final userRole = (snapshot.data ?? _userRole).toUpperCase();
        final isStudent = _isStudentRole(userRole);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),

            if (isStudent) ...[
              const _HomeFirstStepCard(),
              const SizedBox(height: 14),
              const _StudentQuickActions(),
              const SizedBox(height: 18),
              _buildMisCursosHome(),
              const _SimuladoresBanner(),
              const SizedBox(height: 16),
              const _OrientacionBanner(),
              const SizedBox(height: 20),
            ] else ...[
              // Otros roles (profesor/asesor/admin): igual ofrecemos simuladores.
              const SizedBox(height: 8),
              const _SimuladoresBanner(),
              const SizedBox(height: 20),
            ],

            // Campañas desde admin: si no hay activas, no ocupa espacio.
            _buildAutoScrollingCards(),
          ],
        );
      },
    );
  }

  Widget _buildAutoScrollingCards() => const CampanasCarousel();

  // ============================
  // Mis Cursos (square grid)
  // ============================

  Widget _buildMisCursosHome() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _asistentesService.fetchCursosPorCedula(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final cursos = _activeCourses(snap.data ?? const []);
        if (cursos.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section header — tight spacing
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
              child: Row(
                children: [
                  Text(
                    'Mis Cursos',
                    style: DS.poppins(
                      size: 15,
                      weight: FontWeight.w700,
                      color: DS.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (cursos.isNotEmpty)
                    GestureDetector(
                      onTap: () => context.go('/home/courses'),
                      child: Text(
                        'Ver todos',
                        style: DS.poppins(
                          size: 12,
                          weight: FontWeight.w500,
                          color: DS.purple,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _buildCursosRow(context, cursos),
            const SizedBox(height: 18),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _activeCourses(List<Map<String, dynamic>> cursos) {
    return cursos.where(_isActiveCourse).toList();
  }

  bool _isActiveCourse(Map<String, dynamic> curso) {
    final raw =
        (curso['estado'] ??
                curso['status'] ??
                curso['state'] ??
                curso['estatus'] ??
                curso['activo'] ??
                curso['active'] ??
                '')
            .toString()
            .toLowerCase()
            .trim();

    if (raw.isEmpty) return true;
    if (raw.contains('inactivo') ||
        raw.contains('inactive') ||
        raw.contains('finalizado') ||
        raw.contains('terminado') ||
        raw.contains('cancelado') ||
        raw.contains('baja')) {
      return false;
    }
    if (raw == 'true' ||
        raw == '1' ||
        raw.contains('activo') ||
        raw.contains('active') ||
        raw.contains('inscrito') ||
        raw.contains('en curso')) {
      return true;
    }
    return true;
  }

  Widget _buildCursosRow(
    BuildContext context,
    List<Map<String, dynamic>> cursos,
  ) {
    return SizedBox(
      height: 156,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: cursos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => SizedBox(
          width: cursos.length == 1
              ? MediaQuery.sizeOf(context).width - 32
              : 178,
          child: _CursoCardH(curso: cursos[i], colorIndex: i),
        ),
      ),
    );
  }
}

// ─── Pulsing status dot ───────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final bool isActive;
  const _PulsingDot({required this.isActive});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive
        ? const Color(0xFF34D399)
        : const Color(0xFFEF4444);
    return SizedBox(
      width: 18,
      height: 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _scale,
            builder: (_, __) => Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.28),
                ),
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Next class info (> 60 min) ───────────────────────────────────────────────

class _NextClassInfo extends StatelessWidget {
  final String courseName;
  final String hora;
  final String hoy;

  const _NextClassInfo({
    required this.courseName,
    required this.hora,
    required this.hoy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF181828),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A45)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: DS.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: DS.purple,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Próxima clase · $hoy',
                  style: DS.poppins(size: 11, color: DS.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  courseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DS.poppins(
                    size: 13,
                    weight: FontWeight.w600,
                    color: DS.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            hora,
            style: DS.poppins(
              size: 15,
              weight: FontWeight.w700,
              color: DS.purple,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Next class countdown ring (≤ 60 min) ────────────────────────────────────

class _NextClassCountdown extends StatefulWidget {
  final String courseName;
  final String hora;
  final int minutesLeft;

  const _NextClassCountdown({
    required this.courseName,
    required this.hora,
    required this.minutesLeft,
  });

  @override
  State<_NextClassCountdown> createState() => _NextClassCountdownState();
}

class _NextClassCountdownState extends State<_NextClassCountdown>
    with SingleTickerProviderStateMixin {
  late int _minutes;
  late Timer _timer;
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _minutes = widget.minutesLeft;
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _minutes = (_minutes - 1).clamp(0, 60));
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _minutes / 60.0;
    final urgentColor = _minutes <= 15
        ? const Color(0xFFEF4444)
        : const Color(0xFFFBBF24);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: urgentColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: urgentColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          // Circular countdown
          SizedBox(
            width: 68,
            height: 68,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background ring
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 5,
                  color: urgentColor.withValues(alpha: 0.12),
                ),
                // Countdown ring
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 5,
                  color: urgentColor,
                  strokeCap: StrokeCap.round,
                ),
                // Center countdown text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_minutes',
                      style: DS.poppins(
                        size: 20,
                        weight: FontWeight.w800,
                        color: urgentColor,
                      ),
                    ),
                    Text(
                      'min',
                      style: DS.poppins(size: 9, color: DS.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Tu clase inicia pronto!',
                  style: DS.poppins(
                    size: 11,
                    weight: FontWeight.w600,
                    color: urgentColor,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.courseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DS.poppins(
                    size: 13,
                    weight: FontWeight.w700,
                    color: DS.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'a las ${widget.hora}',
                  style: DS.poppins(size: 12, color: DS.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status dot (pulsing green=online / red=offline) ─────────────────────────

class _StatusDot extends StatefulWidget {
  final bool isOnline;
  const _StatusDot({required this.isOnline});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _ringScale;
  late final Animation<double> _ringAlpha;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: false);
    _ringScale = Tween(
      begin: 0.6,
      end: 2.4,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
    _ringAlpha = Tween(
      begin: 0.85,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.isOnline
        ? const Color(0xFF34D399)
        : const Color(0xFFEF4444);

    return SizedBox(
      width: 14,
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding ring — radiates outward and fades
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Transform.scale(
              scale: _ringScale.value,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor.withValues(alpha: _ringAlpha.value),
                ),
              ),
            ),
          ),
          // Inner solid dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
              border: Border.all(color: DS.bg, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.9),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header action button ─────────────────────────────────────────────────────

class _HeaderActionBtn extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _HeaderActionBtn({required this.onTap, required this.child});

  @override
  State<_HeaderActionBtn> createState() => _HeaderActionBtnState();
}

class _HeaderActionBtnState extends State<_HeaderActionBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}

// ─── Offline banner ───────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 16,
            color: Color(0xFFEF4444),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sin conexión — mostrando datos guardados',
              style: DS.poppins(
                size: 12,
                weight: FontWeight.w500,
                color: const Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Alert data model ─────────────────────────────────────────────────────────

class _AlertData {
  final bool isClass;
  final String title;
  final String subtitle;
  final String time;
  final String date;
  final int minutesLeft; // -1 = no countdown

  const _AlertData({
    required this.isClass,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.date,
    required this.minutesLeft,
  });
}

// ─── Alert zone carousel ──────────────────────────────────────────────────────

class _AlertZoneWidget extends StatefulWidget {
  final AuthService authService;
  final AsistentesService asistentesService;

  const _AlertZoneWidget({
    required this.authService,
    required this.asistentesService,
  });

  @override
  State<_AlertZoneWidget> createState() => _AlertZoneWidgetState();
}

class _AlertZoneWidgetState extends State<_AlertZoneWidget> {
  late Future<List<_AlertData>> _future;
  late PageController _pageCtrl;
  Timer? _slideTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _future = _buildAlerts().then((alerts) {
      if (mounted && alerts.length > 1) _startSlide(alerts.length);
      return alerts;
    });
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _startSlide(int count) {
    _slideTimer?.cancel();
    _slideTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageCtrl.hasClients) return;
      final next = (_currentPage + 1) % count;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  static String? _etapaKey(String raw) {
    switch (raw) {
      case 'PRIMERA':
        return 'primera';
      case 'SEGUNDA':
        return 'segunda';
      case 'TERCERA':
        return 'tercera';
      case 'CUARTA':
        return 'cuarta';
    }
    return null;
  }

  static String _etapaLabel(String raw) {
    switch (raw) {
      case 'PRIMERA':
        return 'Primera cita';
      case 'SEGUNDA':
        return 'Segunda cita';
      case 'TERCERA':
        return 'Tercera cita';
      case 'CUARTA':
        return 'Cuarta cita';
      default:
        return 'Cita agendada';
    }
  }

  // Returns "Hoy", "Mañana" or day name for a date offset
  static String _dateLabel(int dayOffset, String dayName) {
    if (dayOffset == 0) return 'Hoy · $dayName';
    if (dayOffset == 1) return 'Mañana · $dayName';
    return dayName;
  }

  static String _dayNameForWeekday(int weekday) {
    const names = {
      DateTime.monday: 'Lunes',
      DateTime.tuesday: 'Martes',
      DateTime.wednesday: 'Miércoles',
      DateTime.thursday: 'Jueves',
      DateTime.friday: 'Viernes',
      DateTime.saturday: 'Sábado',
      DateTime.sunday: 'Domingo',
    };
    return names[weekday] ?? '';
  }

  Future<List<_AlertData>> _buildAlerts() async {
    final alerts = <_AlertData>[];
    final now = DateTime.now();
    final ahoraMin = now.hour * 60 + now.minute;

    // ── Próxima clase (busca hasta 5 días) ───────────────────────────────────
    try {
      final cursos = await widget.asistentesService.fetchCursosPorCedula();
      Map<String, dynamic>? pCurso;
      Map<String, dynamic>? pHora;
      int? bestMinFromNow;
      int? bestDayOffset;

      for (int offset = 0; offset <= 5; offset++) {
        final checkDate = now.add(Duration(days: offset));
        final diaName = _dayNameForWeekday(checkDate.weekday);

        for (final curso in cursos) {
          final horario = curso['horario'];
          if (horario is! List) continue;
          for (final h in horario) {
            if (h is! Map) continue;
            if ((h['Dia'] ?? '').toString() != diaName) continue;
            final p = (h['Hora inicio'] ?? '').toString().split(':');
            if (p.length < 2) continue;
            final claseMin =
                (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
            // Minutes from now total
            final totalMin = offset == 0
                ? claseMin - ahoraMin
                : (offset * 24 * 60) - ahoraMin + claseMin;
            if (totalMin >= 0) {
              if (bestMinFromNow == null || totalMin < bestMinFromNow) {
                bestMinFromNow = totalMin;
                bestDayOffset = offset;
                pCurso = Map<String, dynamic>.from(curso);
                pHora = Map<String, dynamic>.from(h);
              }
            }
          }
        }
        // Found something today or tomorrow → stop early
        if (bestMinFromNow != null && offset <= 1) break;
      }

      // Solo mostramos la clase si le toca dentro de las próximas 24 h (ese día
      // o muy temprano al siguiente). Más lejos no satura el recuadro.
      if (pCurso != null &&
          pHora != null &&
          bestDayOffset != null &&
          bestMinFromNow! <= 24 * 60) {
        final nombre = (pCurso['nombre'] ?? 'Clase')
            .toString()
            .replaceAll('_', ' ')
            .replaceAll('-', ' ');
        final modalidad = (pHora['Modalidad'] ?? 'Presencial').toString();
        final hora = (pHora['Hora inicio'] ?? '').toString();
        final diaName = _dayNameForWeekday(
          now.add(Duration(days: bestDayOffset)).weekday,
        );
        final minLeft = bestMinFromNow;
        alerts.add(
          _AlertData(
            isClass: true,
            title: nombre,
            subtitle: modalidad,
            time: hora,
            date: _dateLabel(bestDayOffset, diaName),
            minutesLeft: minLeft <= 60 ? minLeft : -1,
          ),
        );
      }
    } catch (_) {}

    // ── Cita OV ──────────────────────────────────────────────────────────────
    try {
      final asistentes = await widget.authService.fetchAsistentesPorCedula();
      if (asistentes.isNotEmpty && asistentes.first is Map<String, dynamic>) {
        final asistente = asistentes.first as Map<String, dynamic>;
        final ov = asistente['orientacionVocacional'];
        if (ov is Map<String, dynamic>) {
          final etapaRaw = (ov['etapaActual'] ?? 'SIN_CITA')
              .toString()
              .toUpperCase();
          if (etapaRaw != 'SIN_CITA') {
            dynamic fechaLike = ov['siguienteCitaISO'];
            if (fechaLike == null) {
              final key = _etapaKey(etapaRaw);
              if (key != null && ov[key] is Map) {
                fechaLike = (ov[key] as Map)['fechaISO'];
              }
            }
            if (fechaLike != null) {
              final apptDate = DateTime.tryParse(
                fechaLike.toString(),
              )?.toLocal();
              if (apptDate != null) {
                final now = DateTime.now();
                final diff = apptDate.difference(now).inMinutes;
                final isToday =
                    apptDate.year == now.year &&
                    apptDate.month == now.month &&
                    apptDate.day == now.day;
                if (diff >= 0 && (isToday || diff <= 24 * 60)) {
                  alerts.add(
                    _AlertData(
                      isClass: false,
                      title: 'Orientación Vocacional',
                      subtitle: _etapaLabel(etapaRaw),
                      time:
                          '${apptDate.hour.toString().padLeft(2, '0')}:${apptDate.minute.toString().padLeft(2, '0')}',
                      date: isToday
                          ? 'Hoy · ${_dayNameForWeekday(now.weekday)}'
                          : '${apptDate.day}/${apptDate.month}',
                      minutesLeft: diff <= 60 ? diff : -1,
                    ),
                  );
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    return alerts;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_AlertData>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final alerts = snap.data ?? [];
        if (alerts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1C28),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: DS.divider.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: DS.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sin clases ni citas próximas',
                    style: DS.poppins(size: 12, color: DS.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Column(
            children: [
              SizedBox(
                height: 96,
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: alerts.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _AlertCard(data: alerts[i]),
                  ),
                ),
              ),
              if (alerts.length > 1) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    alerts.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _currentPage == i ? 18 : 6,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: _currentPage == i
                            ? DS.purple
                            : DS.textSecondary.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

// ─── Alert card ───────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final _AlertData data;
  const _AlertCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = data.isClass
        ? const Color(0xFF9B7FE8)
        : const Color(0xFF60A5FA);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C28),
        borderRadius: BorderRadius.circular(14),
        // Borde uniforme (Flutter no permite borderRadius con bordes de color
        // no uniforme). El acento de color va como barra a la izquierda.
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de acento izquierda
          Container(width: 3, color: color),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      data.isClass
                          ? Icons.class_rounded
                          : Icons.psychology_rounded,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          data.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DS.poppins(
                            size: 13,
                            weight: FontWeight.w700,
                            color: DS.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data.subtitle,
                          style: DS.poppins(size: 11, color: DS.textSecondary),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 10,
                              color: DS.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${data.date}  ·  ${data.time}',
                              style: DS.poppins(
                                size: 11,
                                color: DS.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Right: countdown ring or time badge
                  data.minutesLeft >= 0
                      ? _MiniCountdown(minutes: data.minutesLeft, color: color)
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: color.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            data.time,
                            style: DS.poppins(
                              size: 15,
                              weight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentQuickActions extends StatelessWidget {
  const _StudentQuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickActionData(
        icon: Icons.calendar_month_rounded,
        label: 'Horario',
        detail: 'Tu próxima clase',
        color: DS.cyan,
        route: '/home/horarios-estudiantes',
      ),
      _QuickActionData(
        icon: Icons.science_rounded,
        label: 'Simuladores',
        detail: 'Practica examen',
        color: DS.blue,
        route: '/home/simuladores',
      ),
      _QuickActionData(
        icon: Icons.menu_book_rounded,
        label: 'Cursos',
        detail: 'Continúa aprendiendo',
        color: DS.green,
        route: '/home/courses',
      ),
      _QuickActionData(
        icon: Icons.psychology_rounded,
        label: 'Orientación',
        detail: 'Revisa tu proceso',
        color: DS.orange,
        route: '/home/orientacion',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Accesos rápidos',
            style: DS.poppins(
              size: 15,
              weight: FontWeight.w800,
              color: DS.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          // Dos filas de 2 tarjetas. Cada tarjeta toma su altura natural (sin
          // celdas gigantes como dejaba el GridView con aspect ratio fijo).
          for (var i = 0; i < actions.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _QuickActionTile(data: actions[i])),
                  const SizedBox(width: 10),
                  if (i + 1 < actions.length)
                    Expanded(child: _QuickActionTile(data: actions[i + 1]))
                  else
                    const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActionData {
  final IconData icon;
  final String label;
  final String detail;
  final Color color;
  final String route;

  const _QuickActionData({
    required this.icon,
    required this.label,
    required this.detail,
    required this.color,
    required this.route,
  });
}

class _QuickActionTile extends StatefulWidget {
  final _QuickActionData data;

  const _QuickActionTile({required this.data});

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        context.push(widget.data.route);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        scale: _pressed ? 0.96 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: DS.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.data.color.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: widget.data.color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.data.icon,
                  color: widget.data.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.data.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DS.poppins(
                        size: 12,
                        weight: FontWeight.w800,
                        color: DS.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.data.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DS.poppins(size: 10, color: DS.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mini countdown ring ──────────────────────────────────────────────────────

class _MiniCountdown extends StatefulWidget {
  final int minutes;
  final Color color;
  const _MiniCountdown({required this.minutes, required this.color});

  @override
  State<_MiniCountdown> createState() => _MiniCountdownState();
}

class _MiniCountdownState extends State<_MiniCountdown> {
  late int _minutes;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _minutes = widget.minutes;
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _minutes = (_minutes - 1).clamp(0, 60));
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urgentColor = _minutes <= 15 ? const Color(0xFFEF4444) : widget.color;
    final progress = _minutes / 60.0;

    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: 1.0,
            strokeWidth: 4.5,
            color: urgentColor.withValues(alpha: 0.12),
          ),
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 4.5,
            color: urgentColor,
            strokeCap: StrokeCap.round,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_minutes',
                style: DS.poppins(
                  size: 17,
                  weight: FontWeight.w800,
                  color: urgentColor,
                ),
              ),
              Text('min', style: DS.poppins(size: 8, color: DS.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Curso card (enrolled) ────────────────────────────────────────────────────

// ─── Enrolled curso card — horizontal (thumbnail left, info right) ────────────

class _CursoCardH extends StatelessWidget {
  final Map<String, dynamic> curso;
  final int colorIndex;

  const _CursoCardH({required this.curso, required this.colorIndex});

  static const _cardColors = [
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF9333EA),
  ];

  static const _cardIcons = [
    Icons.book_rounded,
    Icons.science_rounded,
    Icons.calculate_rounded,
    Icons.language_rounded,
    Icons.history_edu_rounded,
    Icons.palette_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final name =
        (curso['nombre'] ?? curso['fullname'] ?? curso['name'] ?? 'Curso')
            .toString()
            .replaceAll('_', ' ')
            .replaceAll('-', ' ');
    final horario = curso['horario'] as List? ?? [];
    final modalidad = horario.isNotEmpty
        ? (horario.first['Modalidad'] ?? 'Presencial').toString()
        : 'Presencial';
    final color = _cardColors[colorIndex % _cardColors.length];
    final icon = _cardIcons[colorIndex % _cardIcons.length];

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        CourseDetailSheet.show(context, curso);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DS.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.14),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 74,
              height: double.infinity,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(child: Icon(icon, color: color, size: 30)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      modalidad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DS.poppins(
                        size: 10,
                        weight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DS.poppins(
                      size: 14,
                      weight: FontWeight.w800,
                      color: DS.textPrimary,
                      height: 1.16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: DS.green,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Curso activo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DS.poppins(
                            size: 11,
                            weight: FontWeight.w700,
                            color: DS.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: DS.textSecondary.withValues(alpha: 0.75),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── NIC Premium banner ───────────────────────────────────────────────────────

class _SimuladoresBanner extends StatelessWidget {
  const _SimuladoresBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/home/simuladores');
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0E3A5F), Color(0xFF134E7A), Color(0xFF1A1C2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DS.blue.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: DS.blue.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: DS.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: DS.blue.withValues(alpha: 0.45)),
                ),
                child: const Icon(
                  Icons.science_rounded,
                  color: Color(0xFF5AB1FF),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simuladores de admisión',
                      style: DS.poppins(
                        size: 15,
                        weight: FontWeight.w700,
                        color: DS.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Practica tu examen real y mide tu progreso',
                      style: DS.poppins(size: 12, color: DS.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Color(0xFF5AB1FF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeFirstStepCard extends StatelessWidget {
  const _HomeFirstStepCard();

  void _open(BuildContext context, UltimaActividad? activity) {
    HapticFeedback.lightImpact();
    if (activity == null) {
      context.push('/home/courses');
      return;
    }

    if (activity.kind == ActividadKind.simulador && activity.sim != null) {
      try {
        final item = SimCatalogItem.fromJson(activity.sim!);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SimuladorRunScreen(item: item)),
        );
        return;
      } catch (_) {}
      context.push('/home/simuladores');
      return;
    }

    context.push('/home/courses');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UltimaActividad?>(
      future: LastActivityService().read(),
      builder: (context, snap) {
        final rawActivity = snap.data;
        final activity = rawActivity?.kind == ActividadKind.simulador
            ? rawActivity
            : null;
        final hasActivity = activity != null;
        final title = hasActivity
            ? 'Retoma ${activity.title.isEmpty ? 'tu recurso' : activity.title}'
            : 'Aprende durante 15 min';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: GestureDetector(
            onTap: () => _open(context, activity),
            child: Container(
              height: 74,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEFE5).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFFA35C).withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA35C).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      hasActivity
                          ? Icons.playlist_play_rounded
                          : Icons.track_changes_rounded,
                      color: const Color(0xFFFFA35C),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRIMER PASO DEL DÍA',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DS.poppins(
                            size: 10,
                            weight: FontWeight.w800,
                            color: DS.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DS.poppins(
                            size: 14,
                            weight: FontWeight.w800,
                            color: DS.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: DS.textPrimary.withValues(alpha: 0.8),
                    size: 26,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Banner prominente de Orientación Vocacional — mismo estilo que el de
/// simuladores, lleva a la pantalla que ya existe (`/home/orientacion`).
class _OrientacionBanner extends StatelessWidget {
  const _OrientacionBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/home/orientacion');
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5A340E), Color(0xFF7A4A13), Color(0xFF1A1C2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DS.orange.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: DS.orange.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: DS.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: DS.orange.withValues(alpha: 0.45)),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Color(0xFFFFB266),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orientación Vocacional',
                      style: DS.poppins(
                        size: 15,
                        weight: FontWeight.w700,
                        color: DS.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Descubre tu carrera ideal y tu proceso',
                      style: DS.poppins(size: 12, color: DS.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Color(0xFFFFB266),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
