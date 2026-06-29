import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Shared colors / helpers (mirror of _SC) ──────────────────────────────────
const _bg = Color(0xFF0C0820);
const _card = Color(0xFF160E2E);
const _purple = Color(0xFF8B5CF6);
const _blue = Color(0xFF3B82F6);
const _green = Color(0xFF10B981);
const _yellow = Color(0xFFFBBF24);
const _pink = Color(0xFFEC4899);
const _orange = Color(0xFFF97316);
const _cyan = Color(0xFF06B6D4);

TextStyle _st(double size, Color color, {FontWeight w = FontWeight.w600}) =>
    TextStyle(
      fontFamily: 'Poppins',
      fontSize: size,
      fontWeight: w,
      color: color,
    );

Widget _backBtn(BuildContext ctx) => GestureDetector(
  onTap: () => Navigator.of(ctx).pop(),
  child: Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.08),
      border: Border.all(color: Colors.white24),
    ),
    child: const Icon(
      Icons.arrow_back_ios_new_rounded,
      color: Colors.white,
      size: 18,
    ),
  ),
);

Widget _header(BuildContext ctx, String emoji, String title, Color accent) {
  return Container(
    padding: EdgeInsets.only(
      top: MediaQuery.of(ctx).padding.top + 16,
      left: 22,
      right: 22,
      bottom: 28,
    ),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [accent.withValues(alpha: 0.3), _bg],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: Row(
      children: [
        _backBtn(ctx),
        const SizedBox(width: 16),
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 10),
        Text(title, style: _st(24, Colors.white, w: FontWeight.w900)),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// MI PERFIL
// ═══════════════════════════════════════════════════════════════════════════════
class SteamPerfilScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const SteamPerfilScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final nombre = (user['nombre'] ?? user['fullName'] ?? 'Explorador')
        .toString();
    final email = (user['email'] ?? '').toString();
    final cedula = (user['cedula'] ?? '').toString();
    final ciudad = (user['city'] ?? '').toString();
    final avatar = (user['avatarUrl'] ?? '').toString();
    final puntos = (user['puntos'] as num?)?.toInt() ?? 0;
    final racha = (user['racha'] as num?)?.toInt() ?? 0;
    final cursos = (user['freeAttempts'] as num?)?.toInt() ?? 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header gradient ──
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 22,
                  right: 22,
                  bottom: 36,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_purple.withValues(alpha: 0.45), _bg],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _backBtn(context),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _purple.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _purple.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            'STEAM ✨',
                            style: _st(12, _purple, w: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    // Avatar
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9333EA), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _purple.withValues(alpha: 0.6),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: avatar.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                avatar,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Text(
                                    '🚀',
                                    style: TextStyle(fontSize: 46),
                                  ),
                                ),
                              ),
                            )
                          : const Center(
                              child: Text('🚀', style: TextStyle(fontSize: 46)),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      nombre,
                      style: _st(26, Colors.white, w: FontWeight.w900),
                      textAlign: TextAlign.center,
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(email, style: _st(13, Colors.white38)),
                    ],
                    const SizedBox(height: 24),
                    // Stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ProfileStat(
                          emoji: '⭐',
                          value: '$puntos',
                          label: 'Puntos',
                          color: _yellow,
                        ),
                        const SizedBox(width: 12),
                        _ProfileStat(
                          emoji: '🔥',
                          value: '$racha',
                          label: 'Racha',
                          color: _orange,
                        ),
                        const SizedBox(width: 12),
                        _ProfileStat(
                          emoji: '📚',
                          value: '$cursos',
                          label: 'Cursos',
                          color: _cyan,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Info cards ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mis datos',
                      style: _st(18, Colors.white, w: FontWeight.w900),
                    ),
                    const SizedBox(height: 14),
                    _InfoCard(
                      icon: Icons.badge_rounded,
                      color: _purple,
                      label: 'Cédula',
                      value: cedula.isNotEmpty ? cedula : '—',
                    ),
                    _InfoCard(
                      icon: Icons.location_city_rounded,
                      color: _blue,
                      label: 'Ciudad',
                      value: ciudad.isNotEmpty ? ciudad : '—',
                    ),
                    _InfoCard(
                      icon: Icons.email_rounded,
                      color: _green,
                      label: 'Email',
                      value: email.isNotEmpty ? email : '—',
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Mis logros destacados',
                      style: _st(18, Colors.white, w: FontWeight.w900),
                    ),
                    const SizedBox(height: 14),
                    _AchievementRow(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String emoji, value, label;
  final Color color;
  const _ProfileStat({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(value, style: _st(18, Colors.white, w: FontWeight.w900)),
        Text(label, style: _st(11, Colors.white38)),
      ],
    ),
  );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  const _InfoCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _st(11, Colors.white38)),
            Text(value, style: _st(15, Colors.white, w: FontWeight.w700)),
          ],
        ),
      ],
    ),
  );
}

class _AchievementRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      {'emoji': '🥇', 'name': 'Primer\nlogro', 'color': _yellow, 'ok': true},
      {'emoji': '🔬', 'name': 'Científico', 'color': _blue, 'ok': true},
      {'emoji': '🎨', 'name': 'Artista', 'color': _pink, 'ok': true},
      {'emoji': '🧮', 'name': 'Matemático', 'color': _green, 'ok': false},
    ];
    return Row(
      children: items
          .map(
            (b) => Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (b['ok'] as bool)
                        ? (b['color'] as Color).withValues(alpha: 0.4)
                        : Colors.white10,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      b['emoji'] as String,
                      style: TextStyle(
                        fontSize: 26,
                        color: (b['ok'] as bool)
                            ? null
                            : const Color(0x44FFFFFF),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      b['name'] as String,
                      style: _st(
                        10,
                        (b['ok'] as bool) ? Colors.white : Colors.white38,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MIS LOGROS
// ═══════════════════════════════════════════════════════════════════════════════
// ─── Rank system ──────────────────────────────────────────────────────────────
class _Rank {
  final String emoji, name;
  final Color color;
  final int minLecciones;
  const _Rank({
    required this.emoji,
    required this.name,
    required this.color,
    required this.minLecciones,
  });
}

const _ranks = [
  _Rank(emoji: '🥉', name: 'Bronce', color: Color(0xFFCD7F32), minLecciones: 0),
  _Rank(emoji: '🥈', name: 'Plata', color: Color(0xFFC0C0C0), minLecciones: 10),
  _Rank(emoji: '🥇', name: 'Oro', color: Color(0xFFFBBF24), minLecciones: 25),
  _Rank(
    emoji: '💎',
    name: 'Diamante',
    color: Color(0xFF06B6D4),
    minLecciones: 50,
  ),
  _Rank(
    emoji: '👑',
    name: 'Maestro',
    color: Color(0xFF8B5CF6),
    minLecciones: 100,
  ),
  _Rank(
    emoji: '🌟',
    name: 'Leyenda',
    color: Color(0xFFEC4899),
    minLecciones: 200,
  ),
];

_Rank _getRank(int lecciones) {
  _Rank current = _ranks.first;
  for (final r in _ranks) {
    if (lecciones >= r.minLecciones) current = r;
  }
  return current;
}

_Rank? _getNextRank(int lecciones) {
  for (final r in _ranks) {
    if (lecciones < r.minLecciones) return r;
  }
  return null;
}

// ─── Materia track ────────────────────────────────────────────────────────────
class _MateriaTrack {
  final String emoji, nombre;
  final Color color;
  final int lecciones;
  const _MateriaTrack({
    required this.emoji,
    required this.nombre,
    required this.color,
    required this.lecciones,
  });
}

// ─── Special badges (solo los desbloqueados tienen impacto visual) ─────────────
class _SpecialBadge {
  final String emoji, nombre, desc;
  final Color color;
  final bool ok;
  const _SpecialBadge({
    required this.emoji,
    required this.nombre,
    required this.desc,
    required this.color,
    required this.ok,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// MIS LOGROS
// ═══════════════════════════════════════════════════════════════════════════════
class SteamLogrosScreen extends StatelessWidget {
  const SteamLogrosScreen({super.key});

  static const List<_MateriaTrack> _materias = [];
  static const List<_SpecialBadge> _specials = [];

  @override
  Widget build(BuildContext context) {
    final totalLecciones = _materias.fold<int>(0, (s, m) => s + m.lecciones);
    final specialUnlocked = _specials.where((s) => s.ok).length;

    if (_materias.isEmpty && _specials.isEmpty) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _bg,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _header(context, '🏅', 'Mis logros', _yellow),
              ),
              const SliverToBoxAdapter(child: _SteamEmptyAchievements()),
            ],
          ),
        ),
      );
    }

    // "Próximos logros": materias más cerca de subir de rango
    final proximos = [..._materias]
      ..sort((a, b) {
        final nextA = _getNextRank(a.lecciones);
        final nextB = _getNextRank(b.lecciones);
        if (nextA == null) return 1;
        if (nextB == null) return -1;
        final faltanA = nextA.minLecciones - a.lecciones;
        final faltanB = nextB.minLecciones - b.lecciones;
        return faltanA.compareTo(faltanB);
      });
    final top3 = proximos
        .where((m) => _getNextRank(m.lecciones) != null)
        .take(3)
        .toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _header(context, '🏅', 'Mis logros', _yellow),
            ),

            // ── XP global summary ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _yellow.withValues(alpha: 0.18),
                        _orange.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _yellow.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Text('⭐', style: TextStyle(fontSize: 38)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$totalLecciones lecciones completadas',
                              style: _st(17, Colors.white, w: FontWeight.w900),
                            ),
                            Text(
                              'en ${_materias.length} materias · $specialUnlocked medallas especiales',
                              style: _st(12, Colors.white54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── SECCIÓN 1: Mis rangos por área ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 0, 14),
                child: Text(
                  'Mis rangos por área',
                  style: _st(18, Colors.white, w: FontWeight.w900),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 168,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _materias.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) =>
                      _MateriaRankCard(materia: _materias[i]),
                ),
              ),
            ),

            // ── SECCIÓN 2: Próximos logros ──
            if (top3.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 14),
                  child: Row(
                    children: [
                      Text(
                        'Próximos logros',
                        style: _st(18, Colors.white, w: FontWeight.w900),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _green.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '¡casi!',
                          style: _st(11, _green, w: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _ProximoLogroCard(materia: top3[i]),
                    childCount: top3.length,
                  ),
                ),
              ),
            ],

            // ── SECCIÓN 3: Medallas especiales ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 14),
                child: Text(
                  'Medallas especiales',
                  style: _st(18, Colors.white, w: FontWeight.w900),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _SpecialBadgeCard(badge: _specials[i]),
                  childCount: _specials.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.82,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SteamEmptyAchievements extends StatelessWidget {
  const _SteamEmptyAchievements();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: _yellow.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _yellow.withValues(alpha: 0.35)),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: _yellow,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aún no hay logros registrados',
              style: _st(18, Colors.white, w: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Tus avances aparecerán aquí cuando completes actividades reales en STEAM.',
              style: _st(13, Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Materia rank card (scroll horizontal) ────────────────────────────────────
class _MateriaRankCard extends StatelessWidget {
  final _MateriaTrack materia;
  const _MateriaRankCard({required this.materia});

  @override
  Widget build(BuildContext context) {
    final rank = _getRank(materia.lecciones);
    final nextRank = _getNextRank(materia.lecciones);
    final pct = nextRank != null
        ? ((materia.lecciones - rank.minLecciones) /
                  (nextRank.minLecciones - rank.minLecciones))
              .clamp(0.0, 1.0)
        : 1.0;

    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: rank.color.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(color: rank.color.withValues(alpha: 0.15), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject emoji + rank badge
          Row(
            children: [
              Text(materia.emoji, style: const TextStyle(fontSize: 24)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: rank.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: rank.color.withValues(alpha: 0.5)),
                ),
                child: Text(rank.emoji, style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            materia.nombre,
            style: _st(13, Colors.white, w: FontWeight.w800),
            maxLines: 1,
          ),
          Text(rank.name, style: _st(11, rank.color, w: FontWeight.w700)),
          const Spacer(),
          // Progress to next
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation(rank.color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            nextRank != null
                ? '${materia.lecciones}/${nextRank.minLecciones} → ${nextRank.name}'
                : '¡Rango máximo! 🌟',
            style: _st(9, Colors.white38),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

// ─── Próximo logro card ───────────────────────────────────────────────────────
class _ProximoLogroCard extends StatelessWidget {
  final _MateriaTrack materia;
  const _ProximoLogroCard({required this.materia});

  @override
  Widget build(BuildContext context) {
    final rank = _getRank(materia.lecciones);
    final nextRank = _getNextRank(materia.lecciones)!;
    final faltan = nextRank.minLecciones - materia.lecciones;
    final pct =
        ((materia.lecciones - rank.minLecciones) /
                (nextRank.minLecciones - rank.minLecciones))
            .clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: nextRank.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Subject
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: materia.color.withValues(alpha: 0.15),
              border: Border.all(color: materia.color.withValues(alpha: 0.35)),
            ),
            child: Center(
              child: Text(materia.emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      materia.nombre,
                      style: _st(14, Colors.white, w: FontWeight.w800),
                    ),
                    const Spacer(),
                    Text(
                      '$faltan lecciones',
                      style: _st(11, nextRank.color, w: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${rank.emoji} ${rank.name}  →  ${nextRank.emoji} ${nextRank.name}',
                  style: _st(11, Colors.white38),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation(nextRank.color),
                    minHeight: 7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Special badge card (grid 3 columnas) ─────────────────────────────────────
class _SpecialBadgeCard extends StatelessWidget {
  final _SpecialBadge badge;
  const _SpecialBadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: badge.ok
            ? badge.color.withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.06),
        width: badge.ok ? 1.5 : 1,
      ),
      boxShadow: badge.ok
          ? [
              BoxShadow(
                color: badge.color.withValues(alpha: 0.2),
                blurRadius: 12,
              ),
            ]
          : null,
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          badge.emoji,
          style: TextStyle(
            fontSize: 32,
            color: badge.ok ? null : const Color(0x33FFFFFF),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          badge.nombre,
          style: _st(
            11,
            badge.ok ? Colors.white : Colors.white30,
            w: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        Text(
          badge.desc,
          style: _st(9, badge.ok ? Colors.white38 : Colors.white24),
          textAlign: TextAlign.center,
          maxLines: 2,
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// MI PROGRESO
// ═══════════════════════════════════════════════════════════════════════════════
class SteamProgresoScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const SteamProgresoScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final puntos = (user['puntos'] as num?)?.toInt() ?? 0;
    final racha = (user['racha'] as num?)?.toInt() ?? 0;
    final nivel = (puntos / 200).floor() + 1;
    final pctNivel = ((puntos % 200) / 200).clamp(0.0, 1.0);

    final materias = [
      {'nombre': 'Matemáticas', 'emoji': '🧮', 'color': _green, 'pct': 0.72},
      {'nombre': 'Ciencias', 'emoji': '🔬', 'color': _blue, 'pct': 0.55},
      {'nombre': 'Arte', 'emoji': '🎨', 'color': _pink, 'pct': 0.88},
      {'nombre': 'Tecnología', 'emoji': '💻', 'color': _purple, 'pct': 0.30},
      {'nombre': 'Lenguaje', 'emoji': '📖', 'color': _yellow, 'pct': 0.61},
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _header(context, '📊', 'Mi progreso', _blue),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Level card
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _purple.withValues(alpha: 0.3),
                            _blue.withValues(alpha: 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: _purple.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('🌟', style: TextStyle(fontSize: 28)),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nivel $nivel',
                                    style: _st(
                                      22,
                                      Colors.white,
                                      w: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'Explorador STEAM',
                                    style: _st(12, Colors.white54),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _yellow.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _yellow.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  '$puntos XP',
                                  style: _st(14, _yellow, w: FontWeight.w900),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: pctNivel,
                                    backgroundColor: Colors.white10,
                                    valueColor: const AlwaysStoppedAnimation(
                                      _purple,
                                    ),
                                    minHeight: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Nivel ${nivel + 1}',
                                style: _st(12, Colors.white38),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${(pctNivel * 100).toInt()}% hacia el siguiente nivel',
                            style: _st(11, Colors.white38),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Stats row
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                            emoji: '🔥',
                            value: '$racha días',
                            label: 'Racha actual',
                            color: _orange,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MiniStat(
                            emoji: '✅',
                            value: '12',
                            label: 'Lecciones',
                            color: _green,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MiniStat(
                            emoji: '⏱',
                            value: '4.2h',
                            label: 'Estudiado',
                            color: _cyan,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    Text(
                      'Progreso por materia',
                      style: _st(18, Colors.white, w: FontWeight.w900),
                    ),
                    const SizedBox(height: 16),

                    ...materias.map(
                      (m) => _MateriaBar(
                        emoji: m['emoji'] as String,
                        nombre: m['nombre'] as String,
                        color: m['color'] as Color,
                        pct: m['pct'] as double,
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String emoji, value, label;
  final Color color;
  const _MiniStat({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        Text(
          value,
          style: _st(14, Colors.white, w: FontWeight.w900),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: _st(10, Colors.white38),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _MateriaBar extends StatelessWidget {
  final String emoji, nombre;
  final Color color;
  final double pct;
  const _MateriaBar({
    required this.emoji,
    required this.nombre,
    required this.color,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text(nombre, style: _st(15, Colors.white, w: FontWeight.w700)),
            const Spacer(),
            Text(
              '${(pct * 100).toInt()}%',
              style: _st(14, color, w: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// NOTIFICACIONES
// ═══════════════════════════════════════════════════════════════════════════════
class SteamNotificacionesScreen extends StatelessWidget {
  const SteamNotificacionesScreen({super.key});

  static const _notifs = [
    {
      'emoji': '🔥',
      'title': '¡Racha en peligro!',
      'body': 'Estudia hoy para no perder tu racha de 3 días',
      'time': 'hace 5 min',
      'color': 0xFFF97316,
      'read': false,
    },
    {
      'emoji': '⭐',
      'title': '¡Nuevo logro desbloqueado!',
      'body': 'Obtuviste la medalla "Científico" — ¡felicitaciones!',
      'time': 'hace 2h',
      'color': 0xFFFBBF24,
      'read': false,
    },
    {
      'emoji': '📚',
      'title': 'Nueva lección disponible',
      'body': 'Tu profe publicó contenido nuevo en Matemáticas',
      'time': 'ayer',
      'color': 0xFF8B5CF6,
      'read': true,
    },
    {
      'emoji': '🎯',
      'title': 'Desafío del día',
      'body': '¿Puedes completar el desafío de hoy en menos de 5 min?',
      'time': 'ayer',
      'color': 0xFF3B82F6,
      'read': true,
    },
    {
      'emoji': '🏆',
      'title': '¡Subiste de nivel!',
      'body': 'Ahora eres Nivel 2 — ¡sigue así explorador!',
      'time': 'hace 3 días',
      'color': 0xFFFBBF24,
      'read': true,
    },
    {
      'emoji': '👋',
      'title': 'Bienvenido a NIC STEAM',
      'body': 'Tu aventura de aprendizaje comienza aquí. ¡Vamos!',
      'time': 'hace 1 sem',
      'color': 0xFF10B981,
      'read': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final unread = _notifs.where((n) => n['read'] == false).length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 22,
                  right: 22,
                  bottom: 28,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_orange.withValues(alpha: 0.3), _bg],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    _backBtn(context),
                    const SizedBox(width: 16),
                    const Text('🔔', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 10),
                    Text(
                      'Notificaciones',
                      style: _st(22, Colors.white, w: FontWeight.w900),
                    ),
                    const Spacer(),
                    if (unread > 0)
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _orange,
                        ),
                        child: Center(
                          child: Text(
                            '$unread',
                            style: _st(13, Colors.white, w: FontWeight.w900),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _NotifCard(notif: _notifs[i]),
                  childCount: _notifs.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final Map<String, dynamic> notif;
  const _NotifCard({required this.notif});

  @override
  Widget build(BuildContext context) {
    final read = notif['read'] as bool;
    final color = Color(notif['color'] as int);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: read ? _card : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: read
              ? Colors.white.withValues(alpha: 0.06)
              : color.withValues(alpha: 0.4),
          width: read ? 1 : 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                notif['emoji'] as String,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notif['title'] as String,
                        style: _st(14, Colors.white, w: FontWeight.w800),
                      ),
                    ),
                    if (!read)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notif['body'] as String,
                  style: _st(12, Colors.white54),
                  maxLines: 2,
                ),
                const SizedBox(height: 6),
                Text(notif['time'] as String, style: _st(11, Colors.white30)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AYUDA
// ═══════════════════════════════════════════════════════════════════════════════
class SteamAyudaScreen extends StatelessWidget {
  const SteamAyudaScreen({super.key});

  static const _faqs = [
    {
      'q': '¿Cómo gano puntos?',
      'a':
          'Completas lecciones, desafíos diarios y mantienes tu racha. ¡Cada actividad suma XP!',
      'emoji': '⭐',
      'color': 0xFFFBBF24,
    },
    {
      'q': '¿Qué es la racha?',
      'a':
          'Es la cantidad de días seguidos que has estudiado. ¡Mantenerla te da bonos de XP extra!',
      'emoji': '🔥',
      'color': 0xFFF97316,
    },
    {
      'q': '¿Cómo desbloqueo medallas?',
      'a':
          'Completando retos específicos. Ve a "Mis logros" para ver qué necesitas para cada una.',
      'emoji': '🏅',
      'color': 0xFFEC4899,
    },
    {
      'q': '¿Qué son los desafíos?',
      'a':
          'Retos especiales que cambian cada día. ¡Son la forma más rápida de ganar XP!',
      'emoji': '🎯',
      'color': 0xFF3B82F6,
    },
    {
      'q': '¿Por qué no veo mis cursos?',
      'a':
          'Tu profesor debe inscribirte en los cursos. Pídele que te agregue a sus clases.',
      'emoji': '📚',
      'color': 0xFF8B5CF6,
    },
    {
      'q': '¿Cómo escaneo el QR?',
      'a':
          'Ve a la pestaña QR en la barra de abajo. Toca el botón para escanear y apunta a cualquier código.',
      'emoji': '📱',
      'color': 0xFF10B981,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header(context, '❓', 'Ayuda', _cyan)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _cyan.withValues(alpha: 0.2),
                            _blue.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _cyan.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Text('🤖', style: TextStyle(fontSize: 40)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '¡Hola! Soy tu asistente',
                                  style: _st(
                                    15,
                                    Colors.white,
                                    w: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Aquí tienes las respuestas más frecuentes',
                                  style: _st(12, Colors.white54),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Preguntas frecuentes',
                      style: _st(18, Colors.white, w: FontWeight.w900),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _FaqCard(faq: _faqs[i]),
                  childCount: _faqs.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 40),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text('📞', style: TextStyle(fontSize: 32)),
                      const SizedBox(height: 10),
                      Text(
                        '¿Necesitas más ayuda?',
                        style: _st(16, Colors.white, w: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Habla con tu profesor o con el equipo NIC Academy',
                        style: _st(13, Colors.white38),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqCard extends StatefulWidget {
  final Map<String, dynamic> faq;
  const _FaqCard({required this.faq});

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.faq['color'] as int);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _open = !_open);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _open ? color.withValues(alpha: 0.10) : _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _open
                ? color.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06),
            width: _open ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.faq['emoji'] as String,
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.faq['q'] as String,
                    style: _st(14, Colors.white, w: FontWeight.w700),
                  ),
                ),
                Icon(
                  _open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: _open ? color : Colors.white30,
                  size: 22,
                ),
              ],
            ),
            if (_open) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.faq['a'] as String,
                  style: _st(13, Colors.white70),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
