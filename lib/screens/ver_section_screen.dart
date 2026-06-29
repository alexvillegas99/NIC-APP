import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

// Figma colors exactos
const _kCard = Color(0xFF1E2029);
const _kBg = Color(0xFF12141D);
const _kDivider = Color(0xFF2A223C);
const _kText = Color(0xFFD1D1D6);
const _kTextDim = Color(0xFF9191A0);
const _kPurple = Color(0xFF672AB5);

class VerSectionScreen extends StatefulWidget {
  final int courseId;
  final Map<String, dynamic> courseData;

  const VerSectionScreen({
    super.key,
    required this.courseId,
    required this.courseData,
  });

  @override
  State<VerSectionScreen> createState() => _VerSectionScreenState();
}

class _VerSectionScreenState extends State<VerSectionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;
  final Set<int> _expandedUnits = {0};

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350))
      ..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  String get _title =>
      (widget.courseData['fullname'] as String? ?? 'Sin nombre').trim();

  String get _description {
    final s = widget.courseData['summary']?.toString().trim() ?? '';
    if (s.isEmpty) {
      return 'Aprende de forma fácil con ejercicios claros y ejemplos útiles.';
    }
    return s;
  }

  List<dynamic> get _grades {
    final g = widget.courseData['grades'];
    if (g is List) return g;
    return [];
  }

  List<Map<String, dynamic>> _buildUnits() {
    const unitSize = 5;
    final units = <Map<String, dynamic>>[];
    for (var i = 0; i < _grades.length; i += unitSize) {
      final end = (i + unitSize).clamp(0, _grades.length);
      units.add({
        'name': 'Unidad ${units.length + 1}',
        'items': _grades.sublist(i, end),
      });
    }
    return units;
  }

  @override
  Widget build(BuildContext context) {
    final units = _buildUnits();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBg,
        body: FadeTransition(
          opacity: _fade,
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: _grades.isEmpty
                    ? _buildEmpty()
                    : _buildContent(units),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 18,
        right: 18,
        bottom: 18,
      ),
      color: _kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back arrow (Figma: simple carret left)
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _kText,
              size: 22,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _kText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: _kText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_grades.length} Lecciones',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: _kText,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Content ───────────────────────────────────────────────────────────────

  Widget _buildContent(List<Map<String, dynamic>> units) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: units.length,
      itemBuilder: (context, i) {
        final unit = units[i];
        final isExpanded = _expandedUnits.contains(i);
        return _UnitBlock(
          unitIndex: i,
          unit: unit,
          isExpanded: isExpanded,
          courseId: widget.courseId,
          courseData: widget.courseData,
          onToggle: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (isExpanded) {
                _expandedUnits.remove(i);
              } else {
                _expandedUnits.add(i);
              }
            });
          },
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.video_library_outlined,
              size: 56, color: _kTextDim.withValues(alpha: 0.4)),
          const SizedBox(height: 14),
          const Text('Sin lecciones disponibles',
              style: TextStyle(
                  fontFamily: 'Poppins', color: _kTextDim, fontSize: 14)),
        ],
      ),
    );
  }
}

// ─── Unit Block ──────────────────────────────────────────────────────────────

class _UnitBlock extends StatelessWidget {
  final int unitIndex;
  final Map<String, dynamic> unit;
  final bool isExpanded;
  final int courseId;
  final Map<String, dynamic> courseData;
  final VoidCallback onToggle;

  const _UnitBlock({
    required this.unitIndex,
    required this.unit,
    required this.isExpanded,
    required this.courseId,
    required this.courseData,
    required this.onToggle,
  });

  List<dynamic> get _items => (unit['items'] as List);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Unit header (Figma: border-top #2A223C) ──
        _UnitHeader(
          unitIndex: unitIndex,
          name: unit['name'] as String,
          itemCount: _items.length,
          isExpanded: isExpanded,
          onTap: onToggle,
        ),

        // ── Expanded content ──
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          child: isExpanded ? _buildExpandedBody(context) : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildExpandedBody(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();

    final currentLesson = _items.first;
    final nextLessons = _items.length > 1 ? _items.sublist(1) : <dynamic>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Current lesson (grande, con botón Empezar) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: _CurrentLessonCard(
            lesson: currentLesson,
            onEmpezar: () => context.push(
              '/home/explorar/$courseId/clase',
              extra: {
                'courseData': courseData,
                'unitIndex': unitIndex,
                'lessonIndex': 0,
                'lesson': currentLesson,
              },
            ),
          ),
        ),

        // ── Siguiente clase ──
        if (nextLessons.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Text(
              'Siguiente clase',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: _kTextDim,
              ),
            ),
          ),
          ...nextLessons.asMap().entries.map((e) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: _NextLessonCard(
                lesson: e.value,
                onTap: () => context.push(
                  '/home/explorar/$courseId/clase',
                  extra: {
                    'courseData': courseData,
                    'unitIndex': unitIndex,
                    'lessonIndex': e.key + 1,
                    'lesson': e.value,
                  },
                ),
              ),
            );
          }),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}

// ─── Unit Header ─────────────────────────────────────────────────────────────

class _UnitHeader extends StatelessWidget {
  final int unitIndex;
  final String name;
  final int itemCount;
  final bool isExpanded;
  final VoidCallback onTap;

  const _UnitHeader({
    required this.unitIndex,
    required this.name,
    required this.itemCount,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _kDivider, width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unidad ${unitIndex + 1}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: _kTextDim,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _kText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$itemCount ${itemCount == 1 ? 'lección' : 'lecciones'}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: _kTextDim,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: isExpanded ? 0 : 0.5,
              duration: const Duration(milliseconds: 250),
              child: const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: _kTextDim,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Current Lesson Card (grande, Figma style) ───────────────────────────────

class _CurrentLessonCard extends StatelessWidget {
  final dynamic lesson;
  final VoidCallback onEmpezar;

  const _CurrentLessonCard({required this.lesson, required this.onEmpezar});

  String get _name {
    if (lesson is! Map) return 'Lección';
    return (lesson['itemname'] ?? lesson['name'] ?? 'Lección')
        .toString()
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 142,
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: info + button
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 8, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _kText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Video • Clase',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: _kTextDim,
                        ),
                      ),
                    ],
                  ),
                  // Empezar button
                  GestureDetector(
                    onTap: onEmpezar,
                    child: Container(
                      height: 34,
                      width: 110,
                      decoration: BoxDecoration(
                        color: _kPurple,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'Empezar',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right: play thumbnail (Figma purple area)
          Container(
            width: 120,
            height: 142,
            decoration: BoxDecoration(
              color: _kPurple.withValues(alpha: 0.25),
              borderRadius:
                  const BorderRadius.horizontal(right: Radius.circular(12)),
            ),
            child: const Icon(
              Icons.play_circle_fill_rounded,
              color: _kPurple,
              size: 44,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Next Lesson Card (pequeño) ───────────────────────────────────────────────

class _NextLessonCard extends StatefulWidget {
  final dynamic lesson;
  final VoidCallback onTap;

  const _NextLessonCard({required this.lesson, required this.onTap});

  @override
  State<_NextLessonCard> createState() => _NextLessonCardState();
}

class _NextLessonCardState extends State<_NextLessonCard> {
  bool _pressed = false;

  String get _name {
    if (widget.lesson is! Map) return 'Lección';
    return (widget.lesson['itemname'] ?? widget.lesson['name'] ?? 'Lección')
        .toString()
        .trim();
  }

  double get _pct {
    if (widget.lesson is! Map) return 0;
    final p = widget.lesson['percentage'] ??
        widget.lesson['grade'] ??
        widget.lesson['nota'];
    return (double.tryParse(p?.toString() ?? '') ?? 0).clamp(0.0, 100.0);
  }

  bool get _completed => _pct >= 60;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 8, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _kText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Video • Clase',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: _kTextDim,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Thumbnail / completion
              Container(
                width: 56,
                height: 80,
                decoration: BoxDecoration(
                  color: _completed
                      ? _kPurple.withValues(alpha: 0.3)
                      : const Color(0xFF2A2B3A),
                  borderRadius:
                      const BorderRadius.horizontal(right: Radius.circular(12)),
                ),
                child: Icon(
                  _completed
                      ? Icons.check_circle_rounded
                      : Icons.play_arrow_rounded,
                  color: _completed ? _kPurple : _kTextDim,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
