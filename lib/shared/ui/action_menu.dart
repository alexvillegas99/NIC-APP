import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../ui/design_system.dart';

class ActionMenu extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final EdgeInsets padding;
  final double maxTileWidth;
  final double tileHeight;

  const ActionMenu({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.maxTileWidth = 300,
    this.tileHeight = 160,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final width = MediaQuery.sizeOf(context).width;
    const crossAxisSpacing = 14.0;
    const mainAxisSpacing = 14.0;
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
          mainAxisExtent: tileHeight,
        ),
        itemBuilder: (_, i) => _ActionTile(data: items[i]),
      ),
    );
  }
}

class _ActionTile extends StatefulWidget {
  final Map<String, dynamic> data;
  const _ActionTile({required this.data});

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _pressed = false;

  static const _tileColors = DS.steamColors;

  @override
  Widget build(BuildContext context) {
    final bool highlight = (widget.data['highlight'] ?? false) as bool;
    final IconData icon = (widget.data['icon'] as IconData?) ?? Icons.apps;
    final String text = (widget.data['text'] as String?) ?? '';
    final String? desc = widget.data['description'] as String?;
    final String? route = widget.data['route'] as String?;

    // Color basado en hash del texto para consistencia
    final colorIndex = text.hashCode.abs() % _tileColors.length;
    final tileColor = _tileColors[colorIndex];

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        if (route != null) context.push(route);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E2029),
            borderRadius: BorderRadius.circular(20),
            border: highlight
                ? Border.all(color: tileColor.withValues(alpha: 0.4), width: 1.5)
                : Border.all(color: const Color(0xFF2A2A3A), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icono en cápsula con color
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tileColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: tileColor, size: 24),
                ),
                const SizedBox(height: 12),
                // Título
                Expanded(
                  child: Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DS.poppins(
                      size: 15,
                      weight: FontWeight.w700,
                      color: DS.textPrimary,
                    ),
                  ),
                ),
                if (desc != null && desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DS.poppins(
                      size: 12,
                      weight: FontWeight.w400,
                      color: DS.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: tileColor.withValues(alpha: 0.5),
                    size: 18,
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
