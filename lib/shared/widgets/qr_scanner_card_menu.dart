import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class QRScannerCard extends StatelessWidget {
  final List<Map<String, dynamic>> menuItems;

  const QRScannerCard({super.key, required this.menuItems});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: menuItems.map((item) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: item["highlight"] == true ? Colors.deepPurple.withOpacity(0.1) : Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => context.push(item['route']),
            borderRadius: BorderRadius.circular(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item['icon'], size: 40, color: const Color(0xFF672BB6)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['text'],
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      if (item.containsKey("description")) // 🔹 Mostrar descripción si está presente
                        Text(
                          item["description"],
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
