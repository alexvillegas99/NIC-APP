import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:nic_pre_u/screens/course_detail_sheet.dart';
import 'package:nic_pre_u/screens/simuladores/simulador_run_screen.dart';
import 'package:nic_pre_u/services/asistentes_service.dart';
import 'package:nic_pre_u/services/auth_service.dart';
import 'package:nic_pre_u/services/course_service.dart';
import 'package:nic_pre_u/services/last_activity_service.dart';
import 'package:nic_pre_u/services/simulador_service.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';
import 'package:nic_pre_u/shared/widgets/nic_bottom_nav.dart';

class CoursesListScreen extends StatefulWidget {
  final CourseService service;
  const CoursesListScreen({super.key, required this.service});

  @override
  State<CoursesListScreen> createState() => _CoursesListScreenState();
}

class _CoursesListScreenState extends State<CoursesListScreen>
    with SingleTickerProviderStateMixin {
  final _auth = AuthService();
  final _asist = AsistentesService();

  late Future<_CoursesData> _future;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _future = _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<_CoursesData> _loadData() async {
    final user = await _auth.getUser() ?? {};
    final cursos = await _asist.fetchCursosPorCedula();
    return _CoursesData(user: user, cursos: cursos);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: DS.bg,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: FutureBuilder<_CoursesData>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: SizedBox.shrink());
                  }
                  final data = snap.data ?? _CoursesData(user: {}, cursos: []);
                  return FadeTransition(
                    opacity: _fade,
                    child: RefreshIndicator(
                      color: DS.purple,
                      backgroundColor: DS.card,
                      onRefresh: () async {
                        setState(() => _future = _loadData());
                        _fadeCtrl.reset();
                        _fadeCtrl.forward();
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.only(bottom: 28),
                        children: [
                          _PlanWorldCard(cursos: data.cursos),
                          const SizedBox(height: 18),
                          _PlanEstudiosCard(user: data.user),
                          const SizedBox(height: 16),
                          if (data.cursos.isNotEmpty)
                            _HorarioSection(cursos: data.cursos),
                          if (data.cursos.isNotEmpty)
                            const SizedBox(height: 16),
                          _RachaRankingRow(user: data.user),
                          const SizedBox(height: 16),
                          if (data.cursos.isNotEmpty) ...[
                            _MisCursosSection(cursos: data.cursos),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const NicBottomNav(current: NavTab.cursos),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 14,
      ),
      decoration: BoxDecoration(
        color: DS.bg,
        border: Border(
          bottom: BorderSide(color: DS.divider.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Plan',
            style: DS.poppins(
              size: 22,
              weight: FontWeight.w800,
              color: DS.textPrimary,
            ),
          ),
          const Spacer(),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: DS.card,
              shape: BoxShape.circle,
              border: Border.all(color: DS.divider),
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: DS.textSecondary,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

class _CoursesData {
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> cursos;
  const _CoursesData({required this.user, required this.cursos});
}

// ─── Ruta diaria tipo Plan ───────────────────────────────────────────────────

class _PlanWorldCard extends StatefulWidget {
  final List<Map<String, dynamic>> cursos;
  const _PlanWorldCard({required this.cursos});

  @override
  State<_PlanWorldCard> createState() => _PlanWorldCardState();
}

class _PlanWorldCardState extends State<_PlanWorldCard> {
  late final PageController _pageCtrl;
  int _active = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.70);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  String _clean(Object? value, {String fallback = ''}) {
    final text = (value ?? fallback)
        .toString()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();
    return text.isEmpty ? fallback : text;
  }

  List<_PlanWorldResource> _resources(UltimaActividad? activity) {
    final resources = <_PlanWorldResource>[];
    final seenCourses = <String>{};

    final canShowActivity =
        activity != null &&
        (activity.kind == ActividadKind.simulador || widget.cursos.isNotEmpty);

    if (canShowActivity) {
      resources.add(_fromActivity(activity));
    }

    for (final entry in widget.cursos.asMap().entries) {
      if (resources.where((r) => r.course != null).length >= 5) break;
      final curso = entry.value;
      final title = _clean(
        curso['nombre'] ?? curso['fullname'] ?? curso['name'],
        fallback: 'Curso NIC',
      );
      final key = title.toLowerCase();
      if (!seenCourses.add(key)) continue;

      final horario = curso['horario'] as List?;
      final modalidad = horario != null && horario.isNotEmpty
          ? _clean(horario.first['Modalidad'], fallback: 'Curso asignado')
          : _clean(
              curso['modalidad'] ?? curso['modality'],
              fallback: 'Curso asignado',
            );
      final meta = horario != null && horario.isNotEmpty
          ? 'CURSO • ${horario.length} CLASES'
          : 'CURSO • ASIGNADO';
      final color = DS.steamColor(entry.key);
      resources.add(
        _PlanWorldResource(
          title: title,
          subtitle: modalidad,
          meta: meta,
          cta: 'Ver curso',
          icon: _courseIcon(entry.key),
          accent: color,
          route: '/home/courses',
          course: curso,
        ),
      );
    }

    resources.addAll(const [
      _PlanWorldResource(
        title: 'Orientación vocacional',
        subtitle: '7 tests para decidir carrera',
        meta: 'RUTA • 7 MÓDULOS',
        cta: 'Iniciar',
        icon: Icons.psychology_alt_rounded,
        accent: DS.orange,
        route: '/home/orientacion',
      ),
      _PlanWorldResource(
        title: 'Simuladores de admisión',
        subtitle: 'Practica por universidad',
        meta: 'SIMULADOR • PRÁCTICA',
        cta: 'Practicar',
        icon: Icons.science_rounded,
        accent: DS.blue,
        route: '/home/simuladores',
      ),
    ]);

    return resources;
  }

  IconData _courseIcon(int index) {
    const icons = [
      Icons.calculate_rounded,
      Icons.biotech_rounded,
      Icons.menu_book_rounded,
      Icons.public_rounded,
      Icons.edit_note_rounded,
      Icons.functions_rounded,
    ];
    return icons[index % icons.length];
  }

  _PlanWorldResource _fromActivity(UltimaActividad? activity) {
    if (activity == null) {
      return const _PlanWorldResource(
        title: 'Elige tu siguiente paso',
        subtitle: 'Simuladores y orientación listos para avanzar.',
        meta: 'RECURSO • 15 MINUTOS',
        cta: 'Abrir plan',
        icon: Icons.auto_awesome_rounded,
        accent: DS.purple,
        route: '/home/explorar',
      );
    }
    final isSim = activity.kind == ActividadKind.simulador;
    return _PlanWorldResource(
      title: activity.title.isEmpty ? 'Tu recurso' : activity.title,
      subtitle: activity.subtitle.isEmpty
          ? (isSim
                ? 'Simulador listo para retomar'
                : 'Curso listo para retomar')
          : activity.subtitle,
      meta: isSim ? 'SIMULADOR • PRÁCTICA' : 'CURSO • EN PROGRESO',
      cta: isSim ? 'Practicar' : 'Retomar',
      icon: isSim ? Icons.science_rounded : Icons.menu_book_rounded,
      accent: isSim ? DS.blue : DS.green,
      route: isSim ? '/home/simuladores' : '/home/courses',
      activity: activity,
    );
  }

  void _open(BuildContext context, _PlanWorldResource resource) {
    HapticFeedback.mediumImpact();
    if (resource.course != null) {
      CourseDetailSheet.show(context, resource.course!);
      return;
    }

    final activity = resource.activity;
    if (activity == null) {
      context.push(resource.route);
      return;
    }

    if (activity.kind == ActividadKind.simulador && activity.sim != null) {
      try {
        final item = SimCatalogItem.fromJson(activity.sim!);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SimuladorRunScreen(item: item)),
        );
        return;
      } catch (_) {}
      context.push('/home/simuladores');
      return;
    }

    context.push('/home/courses');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UltimaActividad?>(
      future: LastActivityService().read(),
      builder: (context, snap) {
        final resources = _resources(snap.data);
        final activeIndex = _active.clamp(0, resources.length - 1).toInt();
        return Column(
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                'Construye tus cimientos',
                textAlign: TextAlign.center,
                style: DS.poppins(
                  size: 26,
                  weight: FontWeight.w900,
                  color: DS.textPrimary,
                  height: 1.05,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _PlanWorldConnector(color: Colors.white.withValues(alpha: 0.16)),
            _PlanWorldStage(
              resources: resources,
              activeIndex: activeIndex,
              controller: _pageCtrl,
              onPageChanged: (value) => setState(() => _active = value),
              onOpen: (resource) => _open(context, resource),
            ),
            _PlanWorldConnector(color: Colors.white.withValues(alpha: 0.16)),
            const _LockedPlanStage(),
          ],
        );
      },
    );
  }
}

class _PlanWorldResource {
  final String title;
  final String subtitle;
  final String meta;
  final String cta;
  final IconData icon;
  final Color accent;
  final String route;
  final UltimaActividad? activity;
  final Map<String, dynamic>? course;

  const _PlanWorldResource({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.cta,
    required this.icon,
    required this.accent,
    required this.route,
    this.activity,
    this.course,
  });
}

class _PlanWorldConnector extends StatelessWidget {
  final Color color;
  const _PlanWorldConnector({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          3,
          (_) => Container(
            width: 8,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanWorldStage extends StatelessWidget {
  final List<_PlanWorldResource> resources;
  final int activeIndex;
  final PageController controller;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<_PlanWorldResource> onOpen;

  const _PlanWorldStage({
    required this.resources,
    required this.activeIndex,
    required this.controller,
    required this.onPageChanged,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final active = resources[activeIndex];
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.fromLTRB(0, 46, 0, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                active.accent.withValues(alpha: 0.16),
                DS.purple.withValues(alpha: 0.045),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: active.accent.withValues(alpha: 0.42),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: active.accent.withValues(alpha: 0.18),
                blurRadius: 36,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: [
                    Text(
                      'Desliza y elige tu siguiente paso',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DS.poppins(
                        size: 17,
                        weight: FontWeight.w900,
                        color: const Color(0xFFB6A8E0),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${activeIndex + 1} de ${resources.length} opciones',
                      style: DS.poppins(
                        size: 11,
                        weight: FontWeight.w700,
                        color: DS.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 314,
                child: PageView.builder(
                  controller: controller,
                  itemCount: resources.length,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: onPageChanged,
                  itemBuilder: (context, index) {
                    final selected = index == activeIndex;
                    final resource = resources[index];
                    return AnimatedScale(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      scale: selected ? 1 : 0.88,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: selected ? 1 : 0.46,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: _PlanResourceBook(
                            resource: resource,
                            active: selected,
                            onTap: () => onOpen(resource),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              _PlanCarouselDots(
                count: resources.length,
                activeIndex: activeIndex,
                color: active.accent,
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => onOpen(active),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.playlist_play_rounded,
                        size: 18,
                        color: DS.textPrimary.withValues(alpha: 0.88),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Abrir paso seleccionado',
                        style: DS.poppins(
                          size: 12,
                          weight: FontWeight.w800,
                          color: DS.textPrimary.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -17,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: DS.bg,
              shape: BoxShape.circle,
              border: Border.all(
                color: active.accent.withValues(alpha: 0.20),
                width: 7,
              ),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active.accent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '1',
                style: DS.poppins(
                  size: 12,
                  weight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanCarouselDots extends StatelessWidget {
  final int count;
  final int activeIndex;
  final Color color;

  const _PlanCarouselDots({
    required this.count,
    required this.activeIndex,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: active ? 18 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: active ? color : Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

class _PlanResourceBook extends StatelessWidget {
  final _PlanWorldResource resource;
  final bool active;
  final VoidCallback onTap;
  const _PlanResourceBook({
    required this.resource,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1A26),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
          if (active)
            BoxShadow(
              color: resource.accent.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 0),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 184,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  resource.accent.withValues(alpha: 0.82),
                  const Color(0xFF1E0E3F),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(resource.icon, color: Colors.white, size: 34),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DS.poppins(
                        size: 19,
                        weight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      resource.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DS.poppins(
                        size: 11,
                        weight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.76),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Text(
            resource.meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: DS.poppins(
              size: 11,
              weight: FontWeight.w800,
              color: DS.textSecondary,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _PlanBookButton(
                  label: 'Ver',
                  color: const Color(0xFFF3F3F5),
                  textColor: const Color(0xFF111322),
                  onTap: onTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _PlanBookButton(
                  label: resource.cta,
                  color: resource.accent,
                  textColor: Colors.white,
                  icon: Icons.play_arrow_rounded,
                  onTap: onTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanBookButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;
  final VoidCallback onTap;
  const _PlanBookButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DS.poppins(
                  size: 13,
                  weight: FontWeight.w900,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedPlanStage extends StatelessWidget {
  const _LockedPlanStage();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 54),
          height: 190,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Practica las ideas',
                style: DS.poppins(
                  size: 18,
                  weight: FontWeight.w900,
                  color: DS.textPrimary.withValues(alpha: 0.40),
                ),
              ),
              const SizedBox(height: 16),
              Icon(
                Icons.lock_outline_rounded,
                size: 56,
                color: DS.textPrimary.withValues(alpha: 0.18),
              ),
              const SizedBox(height: 14),
              Text(
                'Completa el paso anterior para\ndesbloquear',
                textAlign: TextAlign.center,
                style: DS.poppins(
                  size: 12,
                  color: DS.textPrimary.withValues(alpha: 0.34),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -15,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DS.bg,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 7,
              ),
            ),
            child: Text(
              '2',
              style: DS.poppins(
                size: 12,
                weight: FontWeight.w900,
                color: DS.textPrimary.withValues(alpha: 0.32),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Plan de estudios ─────────────────────────────────────────────────────────

class _PlanEstudiosCard extends StatelessWidget {
  final Map<String, dynamic> user;
  const _PlanEstudiosCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final plan = user['planEstudios'] as Map<String, dynamic>?;
    final hasPlan = plan != null && plan.isNotEmpty;

    if (!hasPlan) {
      return _buildSetupCTA(context);
    }
    return _buildPlanCard(plan);
  }

  Widget _buildSetupCTA(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: DS.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: DS.purple.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: DS.purple.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: DS.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: DS.purple.withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.map_rounded, color: DS.purple, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plan de estudios',
                    style: DS.poppins(
                      size: 14,
                      weight: FontWeight.w700,
                      color: DS.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Define tus horas, intensidad y metas',
                    style: DS.poppins(size: 12, color: DS.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF9B7FE8)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Configurar',
                  style: DS.poppins(
                    size: 12,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final horas = plan['horasPorSemana'] ?? 10;
    final intensidad = (plan['intensidad'] ?? 'Normal').toString();
    final meta = (plan['meta'] ?? 'Aprobar el año').toString();

    Color intensidadColor;
    IconData intensidadIcon;
    switch (intensidad.toLowerCase()) {
      case 'intensivo':
        intensidadColor = const Color(0xFFEF4444);
        intensidadIcon = Icons.local_fire_department_rounded;
        break;
      case 'relajado':
        intensidadColor = const Color(0xFF10B981);
        intensidadIcon = Icons.spa_rounded;
        break;
      default:
        intensidadColor = DS.purple;
        intensidadIcon = Icons.school_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DS.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: intensidadColor.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.map_rounded, size: 16, color: intensidadColor),
                const SizedBox(width: 6),
                Text(
                  'Mi plan de estudios',
                  style: DS.poppins(
                    size: 13,
                    weight: FontWeight.w700,
                    color: DS.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: intensidadColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(intensidadIcon, size: 11, color: intensidadColor),
                      const SizedBox(width: 3),
                      Text(
                        intensidad,
                        style: DS.poppins(
                          size: 10,
                          weight: FontWeight.w600,
                          color: intensidadColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _PlanStat(
                  label: 'Horas/semana',
                  value: '$horas h',
                  color: DS.purple,
                  icon: Icons.schedule_rounded,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: DS.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag_rounded,
                          size: 14,
                          color: DS.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            meta,
                            style: DS.poppins(
                              size: 11,
                              color: DS.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _PlanStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: DS.poppins(
                  size: 13,
                  weight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(label, style: DS.poppins(size: 9, color: DS.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Mi Horario ───────────────────────────────────────────────────────────────

class _HorarioSection extends StatelessWidget {
  final List<Map<String, dynamic>> cursos;
  const _HorarioSection({required this.cursos});

  static const _diasOrden = [
    'Lunes',
    'Martes',
    'Miercoles',
    'Jueves',
    'Viernes',
    'Sabado',
    'Domingo',
  ];

  String _diaHoy() {
    const dias = {
      1: 'Lunes',
      2: 'Martes',
      3: 'Miercoles',
      4: 'Jueves',
      5: 'Viernes',
      6: 'Sabado',
      7: 'Domingo',
    };
    return dias[DateTime.now().weekday] ?? 'Lunes';
  }

  Map<String, List<Map<String, dynamic>>> _buildSchedule() {
    final Map<String, List<Map<String, dynamic>>> schedule = {};
    for (final curso in cursos) {
      final horario = curso['horario'] as List? ?? [];
      for (final h in horario) {
        if (h is! Map) continue;
        final dia = (h['Dia'] ?? '').toString();
        if (dia.isEmpty) continue;
        schedule.putIfAbsent(dia, () => []);
        schedule[dia]!.add({
          'nombre': curso['nombre'] ?? 'Curso',
          'inicio': h['Hora inicio'] ?? '',
          'fin': h['Hora fin'] ?? '',
          'modalidad': h['Modalidad'] ?? 'Presencial',
          'aula': h['Aula'] ?? '',
        });
      }
    }
    // Sort by time within each day
    for (final clases in schedule.values) {
      clases.sort(
        (a, b) => (a['inicio'] as String).compareTo(b['inicio'] as String),
      );
    }
    return schedule;
  }

  @override
  Widget build(BuildContext context) {
    final schedule = _buildSchedule();
    if (schedule.isEmpty) return const SizedBox.shrink();
    final hoy = _diaHoy();
    final clasesHoy = schedule[hoy] ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Mi horario',
                style: DS.poppins(
                  size: 15,
                  weight: FontWeight.w700,
                  color: DS.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showCalendar(context, schedule),
                child: Row(
                  children: [
                    Text(
                      'Ver completo',
                      style: DS.poppins(
                        size: 12,
                        weight: FontWeight.w500,
                        color: DS.purple,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: DS.purple,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (clasesHoy.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: DS.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: DS.divider.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    size: 18,
                    color: DS.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Sin clases hoy · $hoy',
                    style: DS.poppins(size: 13, color: DS.textSecondary),
                  ),
                ],
              ),
            )
          else
            ...clasesHoy.take(2).map((c) => _ClaseRow(clase: c)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _showCalendar(context, schedule),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: DS.purple.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DS.purple.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: DS.purple,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Ver calendario completo',
                    style: DS.poppins(
                      size: 13,
                      weight: FontWeight.w600,
                      color: DS.purple,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCalendar(
    BuildContext context,
    Map<String, List<Map<String, dynamic>>> schedule,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CalendarSheet(schedule: schedule, diasOrden: _diasOrden),
    );
  }
}

class _ClaseRow extends StatelessWidget {
  final Map<String, dynamic> clase;
  const _ClaseRow({required this.clase});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: DS.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DS.purple.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: DS.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                clase['inicio'] as String,
                style: DS.poppins(
                  size: 12,
                  weight: FontWeight.w800,
                  color: DS.purple,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                (clase['nombre'] as String)
                    .replaceAll('_', ' ')
                    .replaceAll('-', ' '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DS.poppins(
                  size: 13,
                  weight: FontWeight.w600,
                  color: DS.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                clase['modalidad'] as String,
                style: DS.poppins(
                  size: 9,
                  weight: FontWeight.w600,
                  color: const Color(0xFF10B981),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Calendar bottom sheet ────────────────────────────────────────────────────

class _CalendarSheet extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> schedule;
  final List<String> diasOrden;

  const _CalendarSheet({required this.schedule, required this.diasOrden});

  @override
  State<_CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends State<_CalendarSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late int _initialIndex;

  static const _shortDays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _colors = [
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF9333EA),
  ];

  @override
  void initState() {
    super.initState();
    final daysWithClasses = widget.diasOrden
        .where(
          (d) =>
              widget.schedule.containsKey(d) && widget.schedule[d]!.isNotEmpty,
        )
        .toList();
    final hoyName = _hoyNombre();
    _initialIndex = daysWithClasses.indexWhere((d) => d == hoyName);
    if (_initialIndex < 0) _initialIndex = 0;
    _tab = TabController(
      length: daysWithClasses.length,
      vsync: this,
      initialIndex: _initialIndex,
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String _hoyNombre() {
    const dias = {
      1: 'Lunes',
      2: 'Martes',
      3: 'Miercoles',
      4: 'Jueves',
      5: 'Viernes',
      6: 'Sabado',
      7: 'Domingo',
    };
    return dias[DateTime.now().weekday] ?? 'Lunes';
  }

  @override
  Widget build(BuildContext context) {
    final daysWithClasses = widget.diasOrden
        .where(
          (d) =>
              widget.schedule.containsKey(d) && widget.schedule[d]!.isNotEmpty,
        )
        .toList();

    if (daysWithClasses.isEmpty) {
      return Container(
        height: 200,
        decoration: const BoxDecoration(
          color: Color(0xFF141422),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Center(
          child: Text(
            'Sin horario registrado',
            style: DS.poppins(color: DS.textSecondary),
          ),
        ),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141422),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: DS.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: DS.purple,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Mi horario',
                    style: DS.poppins(
                      size: 16,
                      weight: FontWeight.w700,
                      color: DS.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Day tabs
            TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: DS.purple,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: DS.divider.withValues(alpha: 0.4),
              labelStyle: DS.poppins(size: 13, weight: FontWeight.w700),
              unselectedLabelStyle: DS.poppins(size: 13),
              labelColor: DS.purple,
              unselectedLabelColor: DS.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              tabs: daysWithClasses.map((d) {
                final idx = widget.diasOrden.indexOf(d);
                final short = idx >= 0 && idx < _shortDays.length
                    ? _shortDays[idx]
                    : d.substring(0, 3);
                final isHoy = d == _hoyNombre();
                return Tab(
                  child: Row(
                    children: [
                      Text(short),
                      if (isHoy) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: DS.purple,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: daysWithClasses.map((d) {
                  final clases = widget.schedule[d]!;
                  return ListView.separated(
                    controller: ctrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: clases.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final c = clases[i];
                      final color = _colors[i % _colors.length];
                      final nombre = (c['nombre'] as String)
                          .replaceAll('_', ' ')
                          .replaceAll('-', ' ');
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: DS.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: color.withValues(alpha: 0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Time column
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    c['inicio'] as String,
                                    style: DS.poppins(
                                      size: 14,
                                      weight: FontWeight.w800,
                                      color: color,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  c['fin'] as String,
                                  style: DS.poppins(
                                    size: 11,
                                    color: DS.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            // Left border accent
                            Container(
                              width: 3,
                              height: 48,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Course info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nombre,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: DS.poppins(
                                      size: 14,
                                      weight: FontWeight.w700,
                                      color: DS.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      _CalChip(
                                        label: c['modalidad'] as String,
                                        color: color,
                                      ),
                                      if ((c['aula'] as String).isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        _CalChip(
                                          label: 'Aula ${c['aula']}',
                                          color: DS.textSecondary,
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalChip extends StatelessWidget {
  final String label;
  final Color color;
  const _CalChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: DS.poppins(size: 10, weight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ─── Racha + Ranking ──────────────────────────────────────────────────────────

class _RachaRankingRow extends StatelessWidget {
  final Map<String, dynamic> user;
  const _RachaRankingRow({required this.user});

  @override
  Widget build(BuildContext context) {
    final racha = (user['racha'] as int?) ?? 7;
    final posicion = (user['posicion'] as int?) ?? 3;
    final puntos = (user['puntos'] as int?) ?? 420;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.local_fire_department_rounded,
              iconColor: const Color(0xFFFF8C42),
              value: '$racha días',
              label: 'Racha actual',
              bgColor: const Color(0xFFFF8C42).withValues(alpha: 0.1),
              borderColor: const Color(0xFFFF8C42).withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.emoji_events_rounded,
              iconColor: const Color(0xFFFBBF24),
              value: '#$posicion',
              label: 'Tu posición',
              bgColor: const Color(0xFFFBBF24).withValues(alpha: 0.1),
              borderColor: const Color(0xFFFBBF24).withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.stars_rounded,
              iconColor: DS.purple,
              value: '$puntos',
              label: 'Puntos XP',
              bgColor: DS.purple.withValues(alpha: 0.1),
              borderColor: DS.purple.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final Color bgColor;
  final Color borderColor;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 5),
          Text(
            value,
            style: DS.poppins(
              size: 14,
              weight: FontWeight.w800,
              color: DS.textPrimary,
            ),
          ),
          Text(
            label,
            style: DS.poppins(size: 9, color: DS.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Mis Cursos with progress bars ───────────────────────────────────────────

class _MisCursosSection extends StatelessWidget {
  final List<Map<String, dynamic>> cursos;
  const _MisCursosSection({required this.cursos});

  static const _colors = [
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF9333EA),
  ];

  static const _icons = [
    Icons.book_rounded,
    Icons.science_rounded,
    Icons.calculate_rounded,
    Icons.language_rounded,
    Icons.history_edu_rounded,
    Icons.palette_rounded,
  ];

  double _progress(Map<String, dynamic> curso) {
    final grades = curso['grades'] as List?;
    if (grades == null || grades.isEmpty) return 0.0;
    double total = 0;
    int count = 0;
    for (final g in grades) {
      if (g is Map) {
        final grade = double.tryParse(
          (g['grade'] ?? g['nota'] ?? '0').toString(),
        );
        if (grade != null) {
          total += grade.clamp(0, 10);
          count++;
        }
      }
    }
    return count > 0 ? (total / count / 10).clamp(0.0, 1.0) : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    if (cursos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Mis Cursos',
                style: DS.poppins(
                  size: 15,
                  weight: FontWeight.w700,
                  color: DS.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: DS.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${cursos.length} inscrito${cursos.length > 1 ? 's' : ''}',
                  style: DS.poppins(
                    size: 10,
                    weight: FontWeight.w600,
                    color: DS.purple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...cursos.asMap().entries.map((e) {
            final i = e.key;
            final c = e.value;
            final color = _colors[i % _colors.length];
            final icon = _icons[i % _icons.length];
            final nombre = (c['nombre'] ?? 'Curso')
                .toString()
                .replaceAll('_', ' ')
                .replaceAll('-', ' ');
            final prog = _progress(c);
            final pct = (prog * 100).round();
            final horario = c['horario'] as List? ?? [];
            final modalidad = horario.isNotEmpty
                ? (horario.first['Modalidad'] ?? 'Presencial').toString()
                : 'Presencial';

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: DS.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DS.poppins(
                              size: 13,
                              weight: FontWeight.w700,
                              color: DS.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              _CalChip(label: modalidad, color: color),
                              const Spacer(),
                              Text(
                                '$pct%',
                                style: DS.poppins(
                                  size: 12,
                                  weight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: prog,
                              minHeight: 6,
                              backgroundColor: color.withValues(alpha: 0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
