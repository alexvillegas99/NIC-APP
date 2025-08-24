import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nic_pre_u/services/auth_service.dart';
import 'package:nic_pre_u/services/course_service.dart';
import 'package:nic_pre_u/shared/ui/action_menu.dart';
import 'package:nic_pre_u/shared/ui/courses_section.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';
import 'package:nic_pre_u/shared/ui/next_class_card.dart';
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

  final List<String> cardImages = [
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
        final nextPage =
            (_pageController.page!.toInt() + 1) % cardImages.length;
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

  Future<String> _getUserRole() async {
    final userData = await _authService.getUser();

    return userData?['rol'] ?? 'ADMIN';
  }

  Future<String> _getUserName() async {
    final userData = await _authService.getUser();
    final name = userData?['nombre'] ?? userData?['email'] ?? '';
    print('Nombre del usuario: $name');
    return name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DS.bg, // 👈 fondo dark
      body: Stack(
        children: [
          const BackgroundShapes(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header que ya tienes (puedes mantenerlo)
              Container(
                padding: const EdgeInsets.only(
                  top: 40,
                  left: 16,
                  right: 16,
                  bottom: 20,
                ),
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
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatusHeaderCard(), // 👈 NUEVO
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 🔥 Nuevo menú visual usando tu misma data
                      FutureBuilder<String>(
                        future: _getUserRole(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final userRole = snapshot.data ?? "ADMIN";
                          final menuItems = MenuCard(
                            userRole: userRole,
                          ).getMenuItems();
                          return ActionMenu(items: menuItems, columns: 2);
                        },
                      ),

                      const SizedBox(height: 20),
                      CoursesSection(
                        service: CourseService(), // ajusta a tu backend
                        maxItems: 50,
                      ),
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

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'NIC APP',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const LogoutButton(),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return FutureBuilder<String>(
      future: _getUserName(),
      builder: (context, snapshot) {
        final userName = snapshot.data ?? 'Usuario';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hola,',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              userName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Text(
              '¿Qué quieres hacer hoy?',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMenu() {
    return FutureBuilder<String>(
      future: _getUserRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Error al obtener datos"));
        }

        final userRole = snapshot.data ?? "ADMIN";
        final menuItems = MenuCard(userRole: userRole).getMenuItems();

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: QRScannerCard(menuItems: menuItems),
        );
      },
    );
  }

  Widget _buildAutoScrollingCards() {
    return const CampanasCarousel();
  }

  Widget _buildStatusHeaderCard() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _authService.getUser(),
      builder: (context, snap) {
        final user = snap.data ?? {};
        final name = (user['nombre'] ?? user['email'] ?? 'Usuario') as String;
        final activo = (user['estado'] ?? true) as bool; // si tienes ese campo
        final estadoText = activo ? 'Activo' : 'Inactivo';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF111320), // DS.card
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF7C3AED), // morado
                ),
                padding: const EdgeInsets.all(
                  8,
                ), // para que no se pegue a los bordes
                child: Image.asset(
                  'assets/imagenes/logonic.png',
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(width: 12),

              // Texto (ocupa el espacio)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Estado: Activo
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        children: [
                          const TextSpan(text: 'Estado: '),
                          TextSpan(
                            text: estadoText,
                            style: TextStyle(
                              color: activo
                                  ? const Color(0xFF22C55E)
                                  : Colors.redAccent,
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

              // Botón de salida (reusamos tu widget)
              const LogoutButton(),
            ],
          ),
        );
      },
    );
  }
}
