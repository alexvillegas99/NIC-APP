import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nic_pre_u/services/qr_service.dart';
import 'package:nic_pre_u/shared/widgets/background_shapes.dart'; // 🔹 Importa el fondo global

class MyQRScreen extends StatefulWidget {
  const MyQRScreen({super.key});

  @override
  _MyQRScreenState createState() => _MyQRScreenState();
}

class _MyQRScreenState extends State<MyQRScreen> {
  final QRService _qrService = QRService();
  String? qrImageBase64;

  @override
  void initState() {  
    super.initState();
    _loadQRImage();
  }

  Future<void> _loadQRImage() async {
    // Cargar la imagen guardada
    final String? cachedImage = await _qrService.getQRImage();
    if (cachedImage != null) {
      setState(() {
        qrImageBase64 = cachedImage; // Mostrar la imagen guardada mientras se actualiza
      });
    }

    // Generar y guardar una nueva imagen en segundo plano
    await _qrService.generateAndSaveQR();
    final String? newImage = await _qrService.getQRImage();

    if (newImage != null && mounted) {
      setState(() {
        qrImageBase64 = newImage; // Actualizar la imagen cuando esté lista
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 🔹 Fondo limpio y minimalista
      body: Stack(
        children: [
          const BackgroundShapes(), // 🔹 Aplica el fondo global con figuras geométricas
          SafeArea(
            child: Column(
              children: [
                // 🔹 Botón de retroceso
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                const Spacer(),

                // 📌 Título
                const Text(
                  "Este es tu código QR",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(height: 20),

                // 📌 Mostrar el código QR más grande
                Expanded(
                  flex: 3, // 🔹 Ajusta la proporción de espacio
                  child: Center(
                    child: qrImageBase64 != null
                        ? AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500), // 🔹 Animación al actualizar
                            child: Image.memory(
                              base64Decode(qrImageBase64!.split(',')[1]),
                              width: MediaQuery.of(context).size.width * 1, // 🔹 QR más grande
                              fit: BoxFit.contain,
                            ),
                          )
                        : const CircularProgressIndicator(),
                  ),
                ),

                const SizedBox(height: 20),

                // 📌 Texto inferior
                const Text(
                  "Escanéalo para registrar tu asistencia",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),

                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
