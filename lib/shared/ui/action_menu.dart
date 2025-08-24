// lib/shared/widgets/action_menu.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../ui/design_system.dart';

class ActionMenu extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final EdgeInsets padding;
  final int columns;

  const ActionMenu({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.columns = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.90,
        ),
        itemBuilder: (_, i) => _ActionTile(data: items[i]),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ActionTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final bool highlight = (data['highlight'] ?? false) as bool;
    final IconData icon  = (data['icon'] as IconData?) ?? Icons.apps;
    final String text    = (data['text'] as String?) ?? '';
    final String? desc   = data['description'] as String?;
    final String? route  = data['route'] as String?;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
         onTap: route == null ? null : () {
        // Si guardas PATHs absolutos/relativos en 'route'
        context.push(route);

        // Si en vez de path guardas el nombre de ruta:
        // context.pushNamed(route);
      },
      child: Ink(
        decoration: DS.cardDeco(glow: highlight),
        child: Stack(
          children: [
            // Gradiente suave / brillo
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      DS.primary.withOpacity(0.08),
                      DS.primary2.withOpacity(0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icono en cápsula
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: DS.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: DS.text, size: 26),
                  ),
                  const SizedBox(height: 12),
                  Text(text, style: DS.h2),
                  if (desc != null) ...[
                    const SizedBox(height: 6),
                    Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: DS.pDim),
                  ],
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.chevron_right, color: DS.textDim),
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
}
