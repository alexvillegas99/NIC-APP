import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Figma exact colors
const _kBg = Color(0xFF12141D);
const _kNavBg = Color(0xFF2D2B39);
const _kPlayerBg = Color(0xFF161719);
const _kSectionBg = Color(0xFF1A1C25);
const _kDivider = Color(0xFF3F3751);
const _kText = Color(0xFFD1D1D6);
const _kTextDim = Color(0xFF91919F);
const _kPurple = Color(0xFF672AB5);
const _kPurpleLight = Color(0xFF8969CC);

class EmpezarClaseScreen extends StatefulWidget {
  final Map<String, dynamic> courseData;
  final int unitIndex;
  final int lessonIndex;
  final dynamic lesson;

  const EmpezarClaseScreen({
    super.key,
    required this.courseData,
    required this.unitIndex,
    required this.lessonIndex,
    required this.lesson,
  });

  @override
  State<EmpezarClaseScreen> createState() => _EmpezarClaseScreenState();
}

class _EmpezarClaseScreenState extends State<EmpezarClaseScreen>
    with TickerProviderStateMixin {
  int _activeTab = 0; // 0 = Contenido, 1 = Debate
  bool _isPlaying = false;
  double _progress = 0.22;
  final Set<int> _expandedUnits = {};

  late final AnimationController _playCtrl;

  @override
  void initState() {
    super.initState();
    _expandedUnits.add(widget.unitIndex);
    _playCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _playCtrl.dispose();
    super.dispose();
  }

  String get _unitTitle {
    return 'Unidad ${widget.unitIndex + 1}: $_lessonName';
  }

  String get _lessonName {
    if (widget.lesson is! Map) return 'Clase';
    return (widget.lesson['itemname'] ?? widget.lesson['name'] ?? 'Clase')
        .toString()
        .trim();
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
        'subtitle': _unitSubtitle(units.length),
        'items': _grades.sublist(i, end),
      });
    }
    return units;
  }

  String _unitSubtitle(int index) {
    const subs = ['Sustantivos', 'Verbos', 'Adjetivos', 'Oraciones', 'Ejercicios'];
    return subs[index % subs.length];
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBg,
        body: Column(
          children: [
            // ── Navigation header ──
            _buildNavHeader(context),

            // ── Video player ──
            _buildVideoPlayer(),

            // ── Tab bar ──
            _buildTabBar(),

            // ── Content ──
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  // ─── Nav header (Figma: #2d2b39, back + unit title) ──────────────────────

  Widget _buildNavHeader(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      color: _kNavBg,
      padding: EdgeInsets.only(top: topPad + 12, bottom: 12, left: 16, right: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.chevron_left_rounded,
              color: Color(0xFFFCFCFF),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _unitTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Color(0xFFFCFCFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Video player (Figma: #161719, 232px) ────────────────────────────────

  Widget _buildVideoPlayer() {
    return Container(
      height: 232,
      color: _kPlayerBg,
      child: Stack(
        children: [
          // Placeholder artwork gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A1040), Color(0xFF0D0D15)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          // Player controls overlay
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Speed + quality
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _playerChip('1.0X'),
                        const SizedBox(width: 12),
                        _playerChip('480P'),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // Play/Pause + skip controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _skipButton(Icons.replay_10_rounded),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: () {
                        setState(() => _isPlaying = !_isPlaying);
                        HapticFeedback.lightImpact();
                        if (_isPlaying) {
                          _playCtrl.forward();
                        } else {
                          _playCtrl.reverse();
                        }
                      },
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            key: ValueKey(_isPlaying),
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    _skipButton(Icons.forward_10_rounded),
                  ],
                ),
                const Spacer(),
              ],
            ),
          ),

          // Progress bar at bottom
          Positioned(
            bottom: 44,
            left: 20,
            right: 20,
            child: Column(
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: _kPurple,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                    thumbColor: _kPurple,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 3,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: _progress,
                    onChanged: (v) => setState(() => _progress = v),
                  ),
                ),
              ],
            ),
          ),

          // Duration + navigation
          Positioned(
            bottom: 14,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.skip_previous_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    const Text('Previo',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontFamily: 'Poppins')),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.format_align_left_rounded,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    const Text('Subtitulos',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontFamily: 'Poppins')),
                  ],
                ),
                const Text(
                  '0:00 / 1:45',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontFamily: 'Poppins'),
                ),
                Row(
                  children: [
                    const Text('Siguiente',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontFamily: 'Poppins')),
                    const SizedBox(width: 4),
                    const Icon(Icons.skip_next_rounded,
                        color: Colors.white, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerChip(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 11,
        color: Color(0xFFFCFCFF),
      ),
    );
  }

  Widget _skipButton(IconData icon) {
    return GestureDetector(
      onTap: () => HapticFeedback.lightImpact(),
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 32),
    );
  }

  // ─── Tab bar (Figma: Contenido del curso | Debate alumnos) ───────────────

  Widget _buildTabBar() {
    return Row(
      children: [
        _TabItem(
          label: 'Contenido del curso',
          active: _activeTab == 0,
          onTap: () => setState(() => _activeTab = 0),
        ),
        _TabItem(
          label: 'Debate alumnos',
          active: _activeTab == 1,
          onTap: () => setState(() => _activeTab = 1),
        ),
      ],
    );
  }

  // ─── Tab content ──────────────────────────────────────────────────────────

  Widget _buildTabContent() {
    if (_activeTab == 1) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined,
                size: 48, color: _kTextDim.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text(
              'Debate próximamente',
              style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 14, color: _kTextDim),
            ),
          ],
        ),
      );
    }

    // Contenido del curso — accordion
    final units = _buildUnits();
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: units.length,
      itemBuilder: (context, i) {
        final unit = units[i];
        final isExpanded = _expandedUnits.contains(i);
        final items = unit['items'] as List;
        return _ContentUnit(
          index: i,
          subtitle: unit['subtitle'] as String,
          items: items,
          isExpanded: isExpanded,
          currentUnitIndex: widget.unitIndex,
          currentLessonIndex: widget.lessonIndex,
          onToggle: () => setState(() {
            if (isExpanded) {
              _expandedUnits.remove(i);
            } else {
              _expandedUnits.add(i);
            }
          }),
        );
      },
    );
  }
}

// ─── Tab Item ─────────────────────────────────────────────────────────────────

class _TabItem extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          color: active ? _kPurple : _kNavBg,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? Colors.white : const Color(0xFFDADADA),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Content Unit (accordion) ────────────────────────────────────────────────

class _ContentUnit extends StatelessWidget {
  final int index;
  final String subtitle;
  final List<dynamic> items;
  final bool isExpanded;
  final int currentUnitIndex;
  final int currentLessonIndex;
  final VoidCallback onToggle;

  const _ContentUnit({
    required this.index,
    required this.subtitle,
    required this.items,
    required this.isExpanded,
    required this.currentUnitIndex,
    required this.currentLessonIndex,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Unit header
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            color: _kSectionBg,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unidad ${index + 1}. $subtitle',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: _kText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            '${items.length}/${items.length} videos',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              color: _kTextDim,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: _kTextDim,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${items.length * 4} min',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              color: _kTextDim,
                            ),
                          ),
                        ],
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
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Lesson rows
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          child: isExpanded
              ? Column(
                  children: items.asMap().entries.map((e) {
                    final isCurrentLesson =
                        index == currentUnitIndex && e.key == currentLessonIndex;
                    return _LessonRow(
                      index: e.key,
                      lesson: e.value,
                      isCurrent: isCurrentLesson,
                    );
                  }).toList(),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─── Lesson Row ──────────────────────────────────────────────────────────────

class _LessonRow extends StatelessWidget {
  final int index;
  final dynamic lesson;
  final bool isCurrent;

  const _LessonRow({
    required this.index,
    required this.lesson,
    required this.isCurrent,
  });

  String get _name {
    if (lesson is! Map) return 'Lección ${index + 1}';
    return (lesson['itemname'] ?? lesson['name'] ?? 'Lección ${index + 1}')
        .toString()
        .trim();
  }

  double get _pct {
    if (lesson is! Map) return 0;
    final p =
        lesson['percentage'] ?? lesson['grade'] ?? lesson['nota'];
    return (double.tryParse(p?.toString() ?? '') ?? 0).clamp(0.0, 100.0);
  }

  bool get _completed => _pct >= 60 || isCurrent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrent ? _kPurple.withValues(alpha: 0.08) : Colors.transparent,
        border: const Border(
            bottom: BorderSide(color: _kDivider, width: 0.8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}. $_name',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight:
                        isCurrent ? FontWeight.w600 : FontWeight.w400,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Video',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            color: _kTextDim)),
                    const SizedBox(width: 8),
                    Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                            color: _kTextDim, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    const Text('4 min',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            color: _kTextDim)),
                    if (_completed || isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                              color: _kTextDim, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      const Text('Clase vista',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              color: _kTextDim)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Checkbox (Figma: purple when viewed)
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _completed ? _kPurpleLight : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: _completed ? const Color(0xFFA651FF) : _kDivider,
                width: 1.5,
              ),
            ),
            child: _completed
                ? const Icon(Icons.check_rounded,
                    size: 13, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }
}
