import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';

class CampanasCarousel extends StatefulWidget {
  const CampanasCarousel({super.key});

  @override
  State<CampanasCarousel> createState() => _CampanasCarouselState();
}

class _CampanasCarouselState extends State<CampanasCarousel> {
  final PageController _pageController = PageController();
  List<dynamic> _campanas = [];
  int _currentIndex = 0;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _fetchCampanas();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchCampanas() async {
    final String apiUrl = dotenv.env['API_URL'] ?? '';
    if (apiUrl.isEmpty) return;
    try {
      final response = await http.get(Uri.parse('$apiUrl/campanas/activas'));
      if (!mounted) return; // el widget pudo desmontarse durante la petición
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          _campanas = decoded is List ? decoded : [];
        });
      } else {
        debugPrint('Error al obtener campanas: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error al obtener campanas: $e');
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer(const Duration(seconds: 3), () {
      // Si el widget ya no está en el árbol, no tocar setState ni el controller.
      if (!mounted || !_pageController.hasClients || _campanas.isEmpty) return;
      final nextPage = (_currentIndex + 1) % _campanas.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      setState(() => _currentIndex = nextPage);
      _startAutoScroll();
    });
  }

  void _abrirEnlace(String? link) async {
    if (link != null && link.isNotEmpty) {
      final Uri url = Uri.parse(link);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        debugPrint("No se pudo abrir la URL");
      }
    }
  }

  void _compartirEnWhatsApp(String imagenUrl) async {
    final String mensaje = Uri.encodeComponent(
      "Mira esta campana!\nSi quieres acceder a esta promocion, comunicate al +593979164982 \n$imagenUrl",
    );
    final String url = "https://wa.me/?text=$mensaje";

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      debugPrint("No se pudo abrir WhatsApp");
    }
  }

  void _contactarPorWhatsApp(String imagenUrl) async {
    final String numero = "593979164982";
    final String mensaje = Uri.encodeComponent(
      "Hola! Vi esta promocion y me gustaria obtener mas informacion.\n$imagenUrl",
    );
    final String url = "https://wa.me/$numero?text=$mensaje";

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      debugPrint("No se pudo abrir WhatsApp");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_campanas.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              children: [
                Text(
                  'Promociones',
                  style: DS.poppins(
                    size: 14,
                    weight: FontWeight.w800,
                    color: DS.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  'NIC',
                  style: DS.poppins(
                    size: 11,
                    weight: FontWeight.w800,
                    color: DS.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 118,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _campanas.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                final campana = _campanas[index];
                return Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _abrirEnlace(campana['link']),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              campana['imagen'],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => Container(
                                decoration: BoxDecoration(
                                  color: DS.bg,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.image_not_supported_rounded,
                                    color: DS.textSecondary.withValues(
                                      alpha: 0.4,
                                    ),
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Action buttons
                    Positioned(
                      top: 8,
                      right: 28,
                      child: Row(
                        children: [
                          _ActionButton(
                            icon: Icons.share_rounded,
                            onTap: () =>
                                _compartirEnWhatsApp(campana['imagen']),
                          ),
                          const SizedBox(width: 6),
                          _ActionButton(
                            icon: Icons.chat_rounded,
                            onTap: () =>
                                _contactarPorWhatsApp(campana['imagen']),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // Dot indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_campanas.length, (index) {
              final isActive = _currentIndex == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isActive ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [Color(0xFF237EE0), Color(0xFF5030CF)],
                        )
                      : null,
                  color: isActive ? null : Colors.grey.shade300,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: Colors.white, size: 15),
      ),
    );
  }
}
