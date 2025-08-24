import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class CampanasCarousel extends StatefulWidget {
  const CampanasCarousel({super.key});

  @override
  _CampanasCarouselState createState() => _CampanasCarouselState();
}

class _CampanasCarouselState extends State<CampanasCarousel> {
  final PageController _pageController = PageController();
  List<dynamic> _campanas = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchCampanas();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchCampanas() async {
    final String apiUrl = dotenv.env['API_URL'] ?? '';
    final response = await http.get(Uri.parse('$apiUrl/campanas/activas'));

    if (response.statusCode == 200) {
      setState(() {
        _campanas = jsonDecode(response.body);
      });
    } else {
      print('Error al obtener campañas: ${response.statusCode}');
    }
  }

  void _startAutoScroll() {
    Future.delayed(const Duration(seconds: 3), () {
      if (_pageController.hasClients && _campanas.isNotEmpty) {
        final nextPage = (_currentIndex + 1) % _campanas.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        setState(() => _currentIndex = nextPage);
        _startAutoScroll();
      }
    });
  }

  /// 🔹 Abre el link en el navegador si la campaña tiene un link
  void _abrirEnlace(String? link) async {
    if (link != null && link.isNotEmpty) {
      final Uri url = Uri.parse(link);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        print("No se pudo abrir la URL");
      }
    }
  }

  /// 🔹 Función para compartir en WhatsApp con la imagen y el mensaje adicional
  void _compartirEnWhatsApp(String imagenUrl) async {
    final String mensaje = Uri.encodeComponent(
        "¡Mira esta campaña! 🚀\nSi quieres acceder a esta promoción, comunícate al +593979164982 \n$imagenUrl");
    final String url = "https://wa.me/?text=$mensaje";

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      print("No se pudo abrir WhatsApp");
    }
  }

  /// 🔹 Función para contactar directamente en WhatsApp con un mensaje predefinido
  void _contactarPorWhatsApp(String imagenUrl) async {
    final String numero = "593979164982"; // Número de contacto en Ecuador
    final String mensaje = Uri.encodeComponent(
        "¡Hola! Vi esta promoción y me gustaría obtener más información.\n$imagenUrl");
    final String url = "https://wa.me/$numero?text=$mensaje";

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      print("No se pudo abrir WhatsApp");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_campanas.isEmpty)
          const Center(child: CircularProgressIndicator())
        else
          SizedBox(
            height: 200,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _campanas.length,
              itemBuilder: (context, index) {
                final campana = _campanas[index];
                return Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _abrirEnlace(campana['link']), // 🔹 Abre el enlace si existe
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            campana['imagen'],
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 20,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.share, color: Colors.white),
                            onPressed: () => _compartirEnWhatsApp(campana['imagen']),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chat, color: Colors.white),
                            onPressed: () => _contactarPorWhatsApp(campana['imagen']),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _campanas.length,
            (index) => Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentIndex == index ? Colors.black : Colors.grey.shade400,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
