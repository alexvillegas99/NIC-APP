import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum SteamTab { home, desafios, premios, amigos, qr }

class SteamBottomNav extends StatelessWidget {
  final SteamTab current;
  final ValueChanged<SteamTab> onTap;

  const SteamBottomNav({
    super.key,
    required this.current,
    required this.onTap,
  });

  static const _items = [
    _NavItem(tab: SteamTab.home,     icon: Icons.home_rounded,           color: Color(0xFF8B5CF6)),
    _NavItem(tab: SteamTab.desafios, icon: Icons.bolt_rounded,           color: Color(0xFF3B82F6)),
    _NavItem(tab: SteamTab.premios,  icon: Icons.emoji_events_rounded,   color: Color(0xFFFBBF24)),
    _NavItem(tab: SteamTab.amigos,   icon: Icons.favorite_rounded,       color: Color(0xFFEC4899)),
    _NavItem(tab: SteamTab.qr,       icon: Icons.qr_code_2_rounded,      color: Color(0xFF10B981)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0820),
        border: Border(top: BorderSide(color: Color(0xFF1E1040), width: 1.5)),
        boxShadow: [
          BoxShadow(color: Color(0x55000000), blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            children: _items.map((item) => Expanded(
              child: _SteamNavBtn(
                item: item,
                active: current == item.tab,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTap(item.tab);
                },
              ),
            )).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final SteamTab tab;
  final IconData icon;
  final Color color;
  const _NavItem({required this.tab, required this.icon, required this.color});
}

class _SteamNavBtn extends StatefulWidget {
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  const _SteamNavBtn({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  State<_SteamNavBtn> createState() => _SteamNavBtnState();
}

class _SteamNavBtnState extends State<_SteamNavBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 140));
    _scale = Tween(begin: 1.0, end: 0.8).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.item.color;
    final active = widget.active;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox.expand(
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? color.withValues(alpha: 0.22)
                    : Colors.transparent,
                border: active
                    ? Border.all(color: color.withValues(alpha: 0.6), width: 2)
                    : null,
                boxShadow: active
                    ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 14, spreadRadius: 1)]
                    : null,
              ),
              child: Icon(
                widget.item.icon,
                size: active ? 30 : 25,
                color: active ? color : const Color(0xFF4A4870),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
