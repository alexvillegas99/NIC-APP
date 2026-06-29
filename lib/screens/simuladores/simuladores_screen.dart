import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:nic_pre_u/services/auth_service.dart';
import 'package:nic_pre_u/services/simulador_service.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';
import 'package:nic_pre_u/screens/simuladores/simulador_run_screen.dart';

/// Hub / catálogo de simuladores (réplica móvil de /student/simuladores).
class SimuladoresScreen extends StatefulWidget {
  const SimuladoresScreen({super.key});

  @override
  State<SimuladoresScreen> createState() => _SimuladoresScreenState();
}

class _SimuladoresScreenState extends State<SimuladoresScreen> {
  final _service = SimuladorService();
  final _auth = AuthService();

  late Future<List<SimCatalogItem>> _future;
  int _freeAttempts = 0;
  bool _unlimited = false;

  // Universidades (acordeón) expandidas. Por defecto se abre la primera.
  final Set<String> _expandedUnis = {};
  bool _didAutoExpand = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _service.catalog();
    _autoExpandPrimera();
    _loadUser();
  }

  void _autoExpandPrimera() {
    _future.then((items) {
      if (!mounted || _didAutoExpand || items.isEmpty) return;
      setState(() {
        _didAutoExpand = true;
        _expandedUnis.add(_keyUni(items.first));
      });
    }).catchError((_) {});
  }

  static String _keyUni(SimCatalogItem it) =>
      it.uni.isEmpty ? it.nombre : it.uni;

  /// Agrupa los simuladores por universidad conservando el orden de aparición.
  List<_UniGroup> _agrupar(List<SimCatalogItem> items) {
    final orden = <String>[];
    final mapa = <String, List<SimCatalogItem>>{};
    for (final it in items) {
      final k = _keyUni(it);
      if (!mapa.containsKey(k)) {
        orden.add(k);
        mapa[k] = [];
      }
      mapa[k]!.add(it);
    }
    return orden.map((k) => _UniGroup(uni: k, items: mapa[k]!)).toList();
  }

  void _toggleUni(String uni) {
    setState(() {
      if (!_expandedUnis.remove(uni)) _expandedUnis.add(uni);
    });
  }

  /// Filtra universidades por sigla, nombre completo, ciudad o nombre de simulador.
  List<_UniGroup> _filtrar(List<_UniGroup> grupos) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return grupos;
    return grupos.where((g) {
      if (g.uni.toLowerCase().contains(q)) return true;
      if (g.nombreCompleto.toLowerCase().contains(q)) return true;
      return g.items.any((e) =>
          e.ciudad.toLowerCase().contains(q) ||
          e.nombre.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _loadUser() async {
    final user = await _auth.getUser();
    if (!mounted || user == null) return;
    final rol = (user['rol'] ?? user['role'] ?? '').toString().toUpperCase();
    const ilimitados = {
      'ADMIN', 'MAESTRO', 'PROFESOR', 'PSICOLOGO', 'ASESOR',
    };
    setState(() {
      _freeAttempts = (user['freeAttempts'] as num? ?? 0).toInt();
      _unlimited = ilimitados.contains(rol) ||
          (user['accountType'] ?? '').toString() == 'student';
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _service.catalog();
    });
    await _loadUser();
    // El error (incl. 401) lo pinta el FutureBuilder; aquí solo evitamos que
    // el await relance una excepción no capturada.
    try {
      await _future;
    } catch (_) {}
  }

  void _abrir(SimCatalogItem item) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SimuladorRunScreen(item: item),
      ),
    ).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: DS.bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(),
              _searchField(),
              Expanded(
                child: RefreshIndicator(
                  color: DS.purple,
                  backgroundColor: DS.card,
                  onRefresh: _refresh,
                  child: FutureBuilder<List<SimCatalogItem>>(
                    future: _future,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: DS.purple, strokeWidth: 2),
                        );
                      }
                      if (snap.hasError) {
                        return _errorState();
                      }
                      final items = snap.data ?? [];
                      if (items.isEmpty) {
                        return _emptyState();
                      }
                      final todos = _agrupar(items);
                      final grupos = _filtrar(todos);
                      final buscando = _query.trim().isNotEmpty;
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                        children: [
                          _heroStats(todos.length),
                          const SizedBox(height: 16),
                          if (grupos.isEmpty)
                            _noResults()
                          else
                            ...grupos.map((g) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _UniSection(
                                    group: g,
                                    // al buscar, se abren los resultados para ver de una
                                    expanded: buscando ||
                                        _expandedUnis.contains(g.uni),
                                    onToggle: () => _toggleUni(g.uni),
                                    onOpen: _abrir,
                                  ),
                                )),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      decoration: const BoxDecoration(
        color: DS.bg,
        border: Border(bottom: BorderSide(color: Color(0xFF252535))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white, size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Simuladores',
                    style: DS.poppins(
                        size: 19,
                        weight: FontWeight.w800,
                        color: DS.textPrimary)),
                Text('Practica el examen de admisión',
                    style: DS.poppins(size: 11, color: DS.textSecondary)),
              ],
            ),
          ),
          _attemptsChip(),
        ],
      ),
    );
  }

  Widget _attemptsChip() {
    if (_unlimited) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: DS.green.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: DS.green.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.all_inclusive_rounded,
                size: 14, color: DS.green),
            const SizedBox(width: 5),
            Text('Ilimitado',
                style: DS.poppins(
                    size: 11, weight: FontWeight.w700, color: DS.green)),
          ],
        ),
      );
    }
    final color = _freeAttempts > 0 ? DS.yellow : DS.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_freeAttempts > 0 ? Icons.card_giftcard_rounded : Icons.lock_rounded,
              size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            _freeAttempts > 0 ? '$_freeAttempts gratis' : 'Sin intentos',
            style:
                DS.poppins(size: 11, weight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _heroStats(int unis) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D1B69), Color(0xFF1C1C2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DS.purple.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: DS.purple.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.science_rounded,
                color: DS.purple, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$unis universidades disponibles',
                    style: DS.poppins(
                        size: 14,
                        weight: FontWeight.w700,
                        color: DS.textPrimary)),
                const SizedBox(height: 3),
                Text('Simula tu examen real y mide tu progreso',
                    style: DS.poppins(size: 11, color: DS.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Container(
        decoration: BoxDecoration(
          color: DS.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF252535)),
        ),
        child: TextField(
          onChanged: (v) => setState(() => _query = v),
          style: DS.poppins(size: 13, color: DS.textPrimary),
          cursorColor: DS.purple,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Busca tu universidad…',
            hintStyle: DS.poppins(size: 13, color: DS.textSecondary),
            prefixIcon: const Icon(Icons.search_rounded,
                color: DS.textSecondary, size: 20),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: DS.textSecondary, size: 18),
                    onPressed: () {
                      setState(() => _query = '');
                      FocusScope.of(context).unfocus();
                    },
                  ),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          ),
        ),
      ),
    );
  }

  Widget _noResults() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: DS.textSecondary),
          const SizedBox(height: 12),
          Text('Sin resultados para "$_query"',
              textAlign: TextAlign.center,
              style: DS.poppins(size: 13, color: DS.textSecondary)),
          const SizedBox(height: 4),
          Text('Prueba con la sigla, el nombre o la ciudad',
              textAlign: TextAlign.center,
              style: DS.poppins(size: 11, color: DS.textSecondary)),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.science_outlined, size: 56, color: DS.textSecondary),
        const SizedBox(height: 12),
        Center(
          child: Text('No hay simuladores disponibles',
              style: DS.poppins(size: 14, color: DS.textSecondary)),
        ),
      ],
    );
  }

  Widget _errorState() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.cloud_off_rounded, size: 56, color: DS.textSecondary),
        const SizedBox(height: 12),
        Center(
          child: Text('No se pudo cargar el catálogo',
              style: DS.poppins(size: 14, color: DS.textSecondary)),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _refresh,
            child: Text('Reintentar',
                style: DS.poppins(size: 13, color: DS.purple)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Modelo de agrupación: una universidad con sus simuladores
// ─────────────────────────────────────────────────────────────────────────────
class _UniGroup {
  final String uni;
  final List<SimCatalogItem> items;
  _UniGroup({required this.uni, required this.items});

  SimCatalogItem get primero => items.first;
  int get total => items.length;
  int get disponibles => items.where((e) => e.disponible).length;

  /// Total de preguntas disponibles sumando todos los simuladores de la uni.
  int get totalPreguntas => items.fold(0, (s, e) => s + e.totalPreguntas);

  /// Nombre completo legible de la universidad (no la sigla). Busca el primer
  /// simulador cuyo nombre sea el de la universidad (sin el prefijo "UCE · …").
  String get nombreCompleto {
    for (final e in items) {
      final n = e.nombre.trim();
      if (n.isNotEmpty &&
          !n.contains('·') &&
          n.toUpperCase() != uni.toUpperCase() &&
          n.length > uni.length + 1) {
        return n;
      }
    }
    return primero.nombre;
  }
}

/// Quita el prefijo "{uni} · " del nombre del simulador para no repetir la
/// universidad dentro del acordeón ("UCE · Razonamiento Verbal" → "Razonamiento Verbal").
String _examLabel(SimCatalogItem it, String uni) {
  final n = it.nombre.trim();
  for (final sep in const [' · ', ' - ', ': ', ' — ']) {
    final p = '$uni$sep';
    if (n.startsWith(p)) return n.substring(p.length).trim();
  }
  return n;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sección colapsable de una universidad (header + lista de simuladores)
// ─────────────────────────────────────────────────────────────────────────────
class _UniSection extends StatelessWidget {
  final _UniGroup group;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(SimCatalogItem) onOpen;

  const _UniSection({
    required this.group,
    required this.expanded,
    required this.onToggle,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final item0 = group.primero;
    final color = simColor(item0.color);
    final ciudad = group.items
        .map((e) => e.ciudad)
        .firstWhere((c) => c.isNotEmpty, orElse: () => '');
    final nombre = group.nombreCompleto;
    // Línea de identificación: sigla + ciudad (la sigla solo si aporta algo).
    final idLine = [
      if (group.uni.toUpperCase() != nombre.toUpperCase()) group.uni,
      if (ciudad.isNotEmpty) ciudad,
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: DS.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: expanded
              ? color.withValues(alpha: 0.45)
              : const Color(0xFF252535),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Header (toca para expandir/colapsar) ──
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onToggle();
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _LogoBox(item: item0, uni: group.uni, color: color, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nombre,
                              style: DS.poppins(
                                  size: 15,
                                  weight: FontWeight.w800,
                                  color: DS.textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          if (idLine.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(idLine,
                                style: DS.poppins(
                                    size: 11, color: DS.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              _headerPill(
                                  '${group.total} ${group.total == 1 ? "simulador" : "simuladores"}',
                                  color,
                                  fill: true),
                              const SizedBox(width: 6),
                              _headerPill(
                                  '${group.totalPreguntas} preg.',
                                  DS.textSecondary),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Flecha en círculo → afordancia clara de "tócame para abrir"
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: expanded
                            ? color.withValues(alpha: 0.18)
                            : const Color(0xFF252535),
                      ),
                      child: AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Icon(Icons.expand_more_rounded,
                            color: expanded ? color : DS.textSecondary,
                            size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Cuerpo colapsable ──
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 240),
            crossFadeState: expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                for (var i = 0; i < group.items.length; i++) ...[
                  Container(height: 1, color: const Color(0xFF252535)),
                  _ExamRow(
                    item: group.items[i],
                    uni: group.uni,
                    color: color,
                    onTap: group.items[i].disponible
                        ? () => onOpen(group.items[i])
                        : null,
                  ),
                ],
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _headerPill(String text, Color c, {bool fill = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: fill ? 0.15 : 0.0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Text(text,
            style:
                DS.poppins(size: 10, weight: FontWeight.w700, color: c)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Fila de un simulador dentro de una universidad
// ─────────────────────────────────────────────────────────────────────────────
class _ExamRow extends StatelessWidget {
  final SimCatalogItem item;
  final String uni;
  final Color color;
  final VoidCallback? onTap;

  const _ExamRow({
    required this.item,
    required this.uni,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final completo = item.secciones.length > 1;
    // El examen con varias secciones es el "completo"; los demás muestran su nombre.
    final label = completo ? 'Examen completo' : _examLabel(item, uni);

    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: disabled ? DS.textSecondary : color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(label,
                                style: DS.poppins(
                                    size: 14,
                                    weight: FontWeight.w700,
                                    color: DS.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (item.badge != null) ...[
                            const SizedBox(width: 6),
                            _miniBadge(item.badge!, color),
                          ],
                          if (!item.disponible) ...[
                            const SizedBox(width: 6),
                            _miniBadge('PRÓXIMAMENTE', DS.textSecondary),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          _stat(Icons.help_outline_rounded,
                              '${item.totalPreguntas} preg.'),
                          const SizedBox(width: 14),
                          _stat(Icons.schedule_rounded, '${item.totalMin} min'),
                          const SizedBox(width: 14),
                          _stat(Icons.layers_rounded,
                              '${item.secciones.length} secc.'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (!disabled)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 18),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniBadge(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.withValues(alpha: 0.45)),
        ),
        child: Text(text,
            style: DS.poppins(size: 8, weight: FontWeight.w700, color: c)),
      );

  Widget _stat(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: DS.textSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: DS.poppins(
                  size: 11, weight: FontWeight.w500, color: DS.textSecondary)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Caja de logo / glyph de la universidad
// ─────────────────────────────────────────────────────────────────────────────
class _LogoBox extends StatelessWidget {
  final SimCatalogItem item;
  final String uni;
  final Color color;
  final double size;

  const _LogoBox({
    required this.item,
    required this.uni,
    required this.color,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final localLogo = uniLogoFor(uni);
    final inner = size * 0.72;

    Widget content;
    if (item.logoUrl != null) {
      // Override del admin (URL remota) — se muestra a color.
      content = CachedNetworkImage(
        imageUrl: item.logoUrl!,
        width: inner,
        height: inner,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) =>
            localLogo != null ? _asset(localLogo, inner) : _glyph(),
      );
    } else if (localLogo != null) {
      content = _asset(localLogo, inner);
    } else {
      content = _glyph();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // Caja blanca translúcida para que los logos resalten bien.
        color: localLogo != null && item.logoUrl == null
            ? Colors.white.withValues(alpha: 0.10)
            : color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }

  Widget _asset(UniLogo logo, double inner) => Image.asset(
        logo.asset,
        width: inner,
        height: inner,
        fit: BoxFit.contain,
        // Los lineart (mono) se fuerzan a blanco para que se vean sobre el fondo oscuro.
        color: logo.mono ? Colors.white : null,
        colorBlendMode: logo.mono ? BlendMode.srcIn : null,
        errorBuilder: (_, __, ___) => _glyph(),
      );

  Widget _glyph() => Text(
        item.glyph,
        style: DS.poppins(size: 20, weight: FontWeight.w800, color: color),
      );
}
