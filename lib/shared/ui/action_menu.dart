import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../ui/design_system.dart';

class ActionMenu extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final EdgeInsets padding;

  /// Máximo ancho que puede usar cada tile antes de crear una nueva columna.
  /// Ej: 300 → en 600px habrá 2 col, en 900px 3 col, etc.
  final double maxTileWidth;

  /// Alto fijo de cada tile (ajústalo si tu texto es más largo)
  final double tileHeight;

  const ActionMenu({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
    this.maxTileWidth = 300,
    this.tileHeight = 160, // <-- súbelo a 172/180 si aún te queda justo
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final width = MediaQuery.sizeOf(context).width;
    final crossAxisSpacing = 12.0;
    final mainAxisSpacing = 12.0;

    // Cálculo dinámico de columnas: al menos 2
    final cols = (width / maxTileWidth).floor().clamp(2, 6);

    return Padding(
      padding: padding,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: (width - (cols - 1) * crossAxisSpacing - padding.horizontal) / cols + crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          crossAxisSpacing: crossAxisSpacing,
          // Altura fija por tile para evitar overflow por contenido interno
          mainAxisExtent: tileHeight,
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
      onTap: route == null ? null : () => context.push(route),
      child: Ink(
        decoration: DS.cardDeco(glow: highlight),
        child: Stack(
          children: [
            // Gradiente suave
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
                  const SizedBox(height: 10),
                  // Título
                Text(
  text,
  maxLines: 2,              // permite hasta 2 líneas
  overflow: TextOverflow.ellipsis,
  softWrap: true,           // activa salto de línea
  style: DS.h2,
),
                  if (desc != null && desc.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      desc,
                      maxLines: 2, // importa para no romper la altura fija
                      overflow: TextOverflow.ellipsis,
                      style: DS.pDim,
                    ),
                  ],
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Icon(Icons.chevron_right, color: DS.textDim),
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
