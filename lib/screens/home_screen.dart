import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nic_pre_u/services/auth_service.dart';
import 'package:nic_pre_u/services/course_service.dart';
import 'package:nic_pre_u/shared/ui/action_menu.dart';
import 'package:nic_pre_u/shared/ui/courses_section.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';
import 'package:nic_pre_u/shared/widgets/logout_button.dart';
import 'package:nic_pre_u/shared/widgets/qr_scanner_card_menu.dart';
import 'package:nic_pre_u/shared/widgets/menu_card.dart';
import 'package:nic_pre_u/shared/widgets/background_shapes.dart';
import 'package:nic_pre_u/shared/widgets/campanas_carousel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentIndex = 0;

  final List<String> cardImages = const [
    'https://img.freepik.com/foto-gratis/ilustracion-cielo-nocturno-anime_23-2151684328.jpg?semt=ais_hybrid',
    'https://play-lh.googleusercontent.com/3Y1eygZDcaqRwTV51-rdvaJklgH2Whv2h9-Aza2lPyMy2ct5kAi7sNvJlQUwcTDtXV0=w526-h296-rw',
    'https://images3.alphacoders.com/134/1344417.jpeg',
    'https://i.pinimg.com/736x/15/bc/04/15bc04bfc0f824358e48de5a6dc2238d.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients) {
        final nextPage = ((_pageController.page ?? 0).toInt() + 1) % cardImages.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        setState(() => _currentIndex = nextPage);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }
// Extrae OV desde un asistente (respuesta de fetchAsistentesPorCedula)
Map<String, dynamic> _extractOVFromAsistente(Map<String, dynamic> asistente) {
  final ov = asistente['orientacionVocacional'];
  return ov is Map<String, dynamic> ? ov : <String, dynamic>{};
}
  Future<String> _getUserRole() async {
    final userData = await _authService.getUser();
    return userData?['rol'] ?? 'ADMIN';
  }

  Future<String> _getUserName() async {
    final userData = await _authService.getUser();
    final name = userData?['nombre'] ?? userData?['email'] ?? '';
    debugPrint('Nombre del usuario: $name');
    return name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DS.bg,
      body: Stack(
        children: [
          const BackgroundShapes(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatusHeaderCard(),
                    const SizedBox(height: 12),
                    _buildOVStatusCard(), // 👈 OV Card
                  ],
                ),
              ),

              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FutureBuilder<String>(
                        future: _getUserRole(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final userRole = snapshot.data ?? 'ADMIN';
                          final menuItems = MenuCard(userRole: userRole).getMenuItems();
                          return ActionMenu(items: menuItems, columns: 2);
                        },
                      ),
                      const SizedBox(height: 20),
                      CoursesSection(service: CourseService(), maxItems: 50),
                      const SizedBox(height: 20),
                      _buildAutoScrollingCards(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =======================
  // Helpers OV (robustos)
  // =======================

  // Extrae OV del user o de user['asistente']
  Map<String, dynamic> _extractOV(Map<String, dynamic> user) {
    print('userrrrrr: $user');
    final ov1 = user['orientacionVocacional'];
    if (ov1 is Map<String, dynamic>) return ov1;

    final asistente = user['asistente'];
    if (asistente is Map<String, dynamic>) {
      final ov2 = asistente['orientacionVocacional'];
      if (ov2 is Map<String, dynamic>) return ov2;
    }
    return {};
  }

  // Lee "algo que parezca fecha" y lo convierte a ISO String
  String? _readIso(dynamic v) {
    if (v == null) return null;

    if (v is String) {
      return v;
    }
    if (v is DateTime) {
      return v.toUtc().toIso8601String();
    }
    if (v is Map) {
      final d = v[r'$date'];
      if (d is String) return d;
      if (d is int) {
        return DateTime.fromMillisecondsSinceEpoch(d, isUtc: true)
            .toUtc()
            .toIso8601String();
      }
    }
    return null;
  }

  // 'PRIMERA' -> 'primera' (para acceder a ov['primera'])
  String? _etapaKey(String etapaRaw) {
    switch (etapaRaw) {
      case 'PRIMERA': return 'primera';
      case 'SEGUNDA': return 'segunda';
      case 'TERCERA': return 'tercera';
      case 'CUARTA':  return 'cuarta';
    }
    return null;
  }

  // Formatea fecha en español (jue 24 ago, 20:10), con fallback
  String _formatOVDateLike(dynamic isoLike) {
    final iso = _readIso(isoLike);
    if (iso == null || iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('EEE d MMM, HH:mm', 'es').format(d);
    } catch (_) {
      return '—';
    }
  }

  // Etiquetas y colores para etapa
  String _etapaLabel(String raw) {
    switch (raw) {
      case 'PRIMERA': return 'Primera cita';
      case 'SEGUNDA': return 'Segunda cita';
      case 'TERCERA': return 'Tercera cita';
      case 'CUARTA':  return 'Cuarta cita';
      default:        return 'Sin asignar';
    }
  }

  Color _etapaColor(String raw) {
    switch (raw) {
      case 'PRIMERA': return const Color(0xFF60A5FA); // azul
      case 'SEGUNDA': return const Color(0xFFF59E0B); // ámbar
      case 'TERCERA': return const Color(0xFFA78BFA); // violeta
      case 'CUARTA':  return const Color(0xFF34D399); // verde
      default:        return Colors.white60;          // sin asignar
    }
  }

  // =======================
  // UI: Cards
  // =======================

  Widget _ovCard({
    required String etapa,
    required String fecha,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111320),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(.15),
            ),
            child: Icon(Icons.event, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Orientación Vocacional',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: color.withOpacity(.5)),
                      ),
                      child: Text(
                        etapa,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.schedule, size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      fecha,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
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

Widget _buildOVStatusCard() {
  return FutureBuilder<Map<String, dynamic>?>(
    future: _authService.getUser(),
    builder: (context, snapUser) {
      if (snapUser.connectionState != ConnectionState.done) {
        return const SizedBox(); // nada mientras carga
      }

      final user = snapUser.data ?? {};
      print('user en OV: $user');
      final rol = (user['rol'] ?? '').toString().trim();
      print('rol en OV: $rol');
      // 👇 Si tiene rol, no mostrar nada
      if (rol !='ESTUDIANTE') {
        return const SizedBox.shrink();
      }

      // 👇 Si NO tiene rol, mostramos la tarjeta OV como antes
      return FutureBuilder<List<dynamic>>(
        future: _authService.fetchAsistentesPorCedula(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return _ovCard(etapa: 'Cargando…', fecha: '—', color: Colors.grey);
          }
          if (snap.hasError) {
            debugPrint('fetchAsistentesPorCedula error: ${snap.error}');
            return _ovCard(etapa: 'Sin asignar', fecha: '—', color: Colors.grey);
          }

          final lista = snap.data ?? [];
          if (lista.isEmpty || lista.first is! Map<String, dynamic>) {
            return _ovCard(etapa: 'Sin asignar', fecha: '—', color: Colors.grey);
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

          return _ovCard(etapa: etapaBonita, fecha: fechaBonita, color: color);
        },
      );
    },
  );
}

  Widget _buildAutoScrollingCards() => const CampanasCarousel();

  Widget _buildStatusHeaderCard() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _authService.getUser(),
      builder: (context, snap) {
        final user = snap.data ?? {};
        final name = (user['nombre'] ?? user['email'] ?? 'Usuario') as String;
        final activo = (user['estado'] ?? true) as bool;
        final estadoText = activo ? 'Activo' : 'Inactivo';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF111320),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 6)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF7C3AED),
                ),
                padding: const EdgeInsets.all(8),
                child: Image.asset('assets/imagenes/logonic.png', fit: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        children: [
                          const TextSpan(text: 'Estado: '),
                          TextSpan(
                            text: estadoText,
                            style: TextStyle(
                              color: activo ? const Color(0xFF22C55E) : Colors.redAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const LogoutButton(),
            ],
          ),
        );
      },
    );
  }
}
