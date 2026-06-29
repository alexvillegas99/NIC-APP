import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';
import 'package:nic_pre_u/services/auth_service.dart';

// ═══════════════════════════════════════════════════════════════
//  NIC Academy — Onboarding Flow (Screens 3–22)
//  20 pages inside a single PageView, non-swipeable
// ═══════════════════════════════════════════════════════════════

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  // ── Survey answers ──
  final Map<String, dynamic> _answers = {};

  // ── Mini-lesson state ──
  int _quizIndex = 0;
  int _correctCount = 0;
  String? _selectedQuizAnswer;
  bool _quizAnswered = false;
  final Stopwatch _lessonStopwatch = Stopwatch();

  // ── Auth fields ──
  final _nameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _authLoading = false;
  bool _obscurePassword = true;

  // ── Mascot bounce ──
  late AnimationController _mascotBounceCtrl;
  late Animation<double> _mascotBounce;

  // ── Flame scale (streak page) ──
  late AnimationController _flameCtrl;
  late Animation<double> _flameScale;

  // ── Page entrance ──
  late AnimationController _pageEntranceCtrl;
  late Animation<double> _pageFade;
  late Animation<Offset> _pageSlide;

  // ── "Construyendo tu ruta" overlay ──
  bool _showBuildingRoute = false;

  // ── Time picker ──
  TimeOfDay _reminderTime = const TimeOfDay(hour: 18, minute: 0);

  // Quiz data
  static const _quizQuestions = [
    {
      'q': '¿Cuál es la capital de Ecuador?',
      'opts': ['Quito', 'Guayaquil', 'Cuenca', 'Loja'],
      'answer': 'Quito',
    },
    {
      'q': '¿Cuántos lados tiene un triángulo?',
      'opts': ['2', '3', '4', '5'],
      'answer': '3',
    },
  ];

  @override
  void initState() {
    super.initState();

    _mascotBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _mascotBounce = Tween(begin: 0.0, end: -8.0).animate(
      CurvedAnimation(parent: _mascotBounceCtrl, curve: Curves.easeInOut),
    );

    _flameCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _flameScale = Tween(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _flameCtrl, curve: Curves.easeInOut),
    );

    _pageEntranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _pageFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pageEntranceCtrl, curve: Curves.easeOut),
    );
    _pageSlide = Tween(
      begin: const Offset(0.0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _pageEntranceCtrl, curve: Curves.easeOutCubic),
    );

    _pageEntranceCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _mascotBounceCtrl.dispose();
    _flameCtrl.dispose();
    _pageEntranceCtrl.dispose();
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Navigation helpers ──

  void _goNext() {
    if (_currentPage < 19) {
      _pageEntranceCtrl.reset();
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage++);
      _pageEntranceCtrl.forward();
    }
  }

  void _goBack() {
    if (_currentPage > 0) {
      _pageEntranceCtrl.reset();
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage--);
      _pageEntranceCtrl.forward();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    await _persistInterests();
    if (mounted) context.go('/home');
  }

  /// Guarda el interés del estudiante (q1 "¿Qué quieres aprender?") y el resto
  /// de respuestas para poder proponerle un curso acorde la primera vez que
  /// entra al home (tarjeta recomendada con resplandor estilo Headway).
  Future<void> _persistInterests() async {
    final prefs = await SharedPreferences.getInstance();
    final interes = (_answers['q1'] as String?)?.trim();
    if (interes != null && interes.isNotEmpty) {
      await prefs.setString('student_interest', interes);
    }
    await prefs.setString('onboarding_answers', jsonEncode(_answers));
  }

  // ── Survey pages = pages 2..8 (Q1–Q7) ──
  bool get _isSurveyPage => _currentPage >= 2 && _currentPage <= 8;
  int get _surveyIndex => _currentPage - 2; // 0..6

  // ══════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: DS.bg,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // ── Top bar: back + progress ──
                  if (_currentPage > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
                      child: Row(
                        children: [
                          if (_currentPage > 0)
                            IconButton(
                              onPressed: _goBack,
                              icon: const Icon(Icons.arrow_back_rounded,
                                  color: DS.textPrimary),
                            ),
                          if (_isSurveyPage) ...[
                            const SizedBox(width: 8),
                            Expanded(child: _buildProgressDots()),
                          ] else
                            const Spacer(),
                        ],
                      ),
                    ),

                  // ── Pages ──
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _pageEntranceCtrl,
                      builder: (context, child) => FadeTransition(
                        opacity: _pageFade,
                        child: SlideTransition(
                          position: _pageSlide,
                          child: child,
                        ),
                      ),
                      child: PageView(
                        controller: _pageCtrl,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: (i) =>
                            setState(() => _currentPage = i),
                        children: [
                          _page0MascotIntro(),
                          _page1SurveyIntro(),
                          _page2Q1WhatToLearn(),
                          _page3Q2HowDidYouFind(),
                          _page4Q3Level(),
                          _page5Q4Motivation(),
                          _page6Q5Routine(),
                          _page7Q6XPGoal(),
                          _page8Q7Reminder(),
                          _page9WidgetPrompt(),
                          _page10Tutorial(),
                          _page11CourseSummary(),
                          _page12Plans(),
                          _page13FirstLessonIntro(),
                          _page14MiniLesson(),
                          _page15LessonComplete(),
                          _page16Streak(),
                          _page17StreakGoal(),
                          _page18Register(),
                          _page19WelcomeBack(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ── "Construyendo tu ruta" overlay ──
              if (_showBuildingRoute) _buildRouteOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Progress dots for survey (7 questions) ───
  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(7, (i) {
        final isActive = i <= _surveyIndex;
        final isCurrent = i == _surveyIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isCurrent ? 24 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: isActive ? DS.blue : DS.cardSoft,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }

  // ─── "Construyendo tu ruta..." overlay ───
  Widget _buildRouteOverlay() {
    return Container(
      color: DS.bg.withValues(alpha: 0.95),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: DS.blue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Construyendo tu ruta...',
              style: DS.poppins(
                size: 18,
                weight: FontWeight.w600,
                color: DS.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  HELPER WIDGETS
  // ══════════════════════════════════════════════════════════════

  Widget _mascotImage({double size = 160}) {
    return AnimatedBuilder(
      animation: _mascotBounceCtrl,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _mascotBounce.value),
        child: child,
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: DS.mascot,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: DS.cardSoft,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: DS.blue),
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: DS.cardSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school_rounded, size: 60, color: DS.blue),
          ),
        ),
      ),
    );
  }

  Widget _pageWrapper({required List<Widget> children, bool centered = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: centered
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            )
          : ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 32),
              children: children,
            ),
    );
  }

  Widget _selectableCard({
    required String label,
    String? subtitle,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : DS.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : DS.divider,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            if (!selected)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: DS.poppins(
                      size: 15,
                      weight: FontWeight.w600,
                      color: DS.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: DS.poppins(size: 12, color: DS.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? DS.blue.withValues(alpha: 0.1) : DS.card,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected ? DS.blue : DS.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: DS.poppins(
            size: 14,
            weight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? DS.blue : DS.textPrimary,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 0 — Mascot Intro (Screen 3)
  // ══════════════════════════════════════════════════════════════

  Widget _page0MascotIntro() {
    return _pageWrapper(
      children: [
        const Spacer(flex: 2),
        _mascotImage(size: 180),
        const SizedBox(height: 40),
        Text(
          '¡Hola! Soy NIC, tu compañero\nde aprendizaje.',
          textAlign: TextAlign.center,
          style: DS.poppins(
            size: 22,
            weight: FontWeight.w700,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Te voy a ayudar a descubrir\ntu potencial.',
          textAlign: TextAlign.center,
          style: DS.poppins(size: 16, color: DS.textSecondary),
        ),
        const Spacer(flex: 3),
        NicButton(
          text: 'CONTINUAR',
          onPressed: _goNext,
          color: DS.blue,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 1 — Survey Intro (Screen 4)
  // ══════════════════════════════════════════════════════════════

  Widget _page1SurveyIntro() {
    return _pageWrapper(
      children: [
        const Spacer(flex: 2),
        _mascotImage(size: 120),
        const SizedBox(height: 32),
        Text(
          'Responde 7 preguntas cortas\npara personalizar tu experiencia.',
          textAlign: TextAlign.center,
          style: DS.poppins(
            size: 18,
            weight: FontWeight.w600,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 28),
        // 7 empty circles
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            7,
            (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: DS.blue, width: 2),
                color: Colors.transparent,
              ),
            ),
          ),
        ),
        const Spacer(flex: 3),
        NicButton(
          text: 'CONTINUAR',
          onPressed: _goNext,
          color: DS.blue,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 2 — Q1: ¿Qué quieres aprender? (Screen 5)
  // ══════════════════════════════════════════════════════════════

  Widget _page2Q1WhatToLearn() {
    final selected = _answers['q1'] as String?;
    final options = [
      {'label': 'STEAM', 'icon': Icons.science, 'color': DS.blue},
      {'label': 'Idiomas', 'icon': Icons.translate, 'color': DS.purple},
      {
        'label': 'Cursos profesionalizantes',
        'icon': Icons.work,
        'color': DS.orange
      },
      {
        'label': 'Refuerzo académico',
        'icon': Icons.school,
        'color': DS.cyan
      },
      {
        'label': 'Preparación preuniversitaria',
        'icon': Icons.emoji_events,
        'color': DS.green
      },
    ];

    return _pageWrapper(
      centered: false,
      children: [
        const SizedBox(height: 12),
        Text(
          '¿Qué quieres aprender?',
          style: DS.poppins(
            size: 22,
            weight: FontWeight.w700,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        ...options.map((o) {
          final label = o['label'] as String;
          return _selectableCard(
            label: label,
            icon: o['icon'] as IconData,
            color: o['color'] as Color,
            selected: selected == label,
            onTap: () {
              setState(() => _answers['q1'] = label);
              HapticFeedback.selectionClick();
              // Show "building route" then auto-advance
              Future.delayed(const Duration(milliseconds: 300), () {
                if (!mounted) return;
                setState(() => _showBuildingRoute = true);
                Future.delayed(const Duration(milliseconds: 1500), () {
                  if (!mounted) return;
                  setState(() => _showBuildingRoute = false);
                  _goNext();
                });
              });
            },
          );
        }),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 3 — Q2: ¿Cómo nos conociste? (Screen 6)
  // ══════════════════════════════════════════════════════════════

  Widget _page3Q2HowDidYouFind() {
    final selected = _answers['q2'] as String?;
    final options = [
      'Redes sociales',
      'Recomendación de amigo',
      'Publicidad',
      'Mi colegio',
      'Otro',
    ];

    return _pageWrapper(
      children: [
        const Spacer(flex: 2),
        Text(
          '¿Cómo nos conociste?',
          textAlign: TextAlign.center,
          style: DS.poppins(
            size: 22,
            weight: FontWeight.w700,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: options.map((o) {
            return _chip(
              label: o,
              selected: selected == o,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _answers['q2'] = o);
              },
            );
          }).toList(),
        ),
        const Spacer(flex: 3),
        NicButton(
          text: 'CONTINUAR',
          onPressed: selected != null ? _goNext : () {},
          color: selected != null ? DS.blue : DS.cardSoft,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 4 — Q3: ¿Qué nivel tienes? (Screen 7)
  // ══════════════════════════════════════════════════════════════

  Widget _page4Q3Level() {
    final selected = _answers['q3'] as String?;
    final options = [
      {
        'label': 'Principiante',
        'sub': 'Estoy empezando desde cero',
        'color': DS.green,
        'icon': Icons.eco_rounded,
      },
      {
        'label': 'Intermedio',
        'sub': 'Tengo conocimientos básicos',
        'color': DS.blue,
        'icon': Icons.trending_up_rounded,
      },
      {
        'label': 'Avanzado',
        'sub': 'Busco perfeccionar mis habilidades',
        'color': DS.purple,
        'icon': Icons.rocket_launch_rounded,
      },
    ];

    return _pageWrapper(
      centered: false,
      children: [
        const SizedBox(height: 12),
        Text(
          '¿Qué nivel tienes?',
          style: DS.poppins(
            size: 22,
            weight: FontWeight.w700,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        ...options.map((o) {
          final label = o['label'] as String;
          return _selectableCard(
            label: label,
            subtitle: o['sub'] as String,
            icon: o['icon'] as IconData,
            color: o['color'] as Color,
            selected: selected == label,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _answers['q3'] = label);
            },
          );
        }),
        const SizedBox(height: 24),
        NicButton(
          text: 'CONTINUAR',
          onPressed: selected != null ? _goNext : () {},
          color: selected != null ? DS.blue : DS.cardSoft,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 5 — Q4: ¿Qué te motiva? (Screen 8)
  // ══════════════════════════════════════════════════════════════

  Widget _page5Q4Motivation() {
    final selected = _answers['q4'] as String?;
    final options = [
      {'label': 'Aprender algo nuevo', 'icon': Icons.lightbulb_outline},
      {'label': 'Mejorar mis notas', 'icon': Icons.trending_up},
      {'label': 'Preparar un examen', 'icon': Icons.assignment_outlined},
      {'label': 'Desarrollo profesional', 'icon': Icons.work_outline},
    ];

    return _pageWrapper(
      centered: false,
      children: [
        const SizedBox(height: 12),
        Text(
          '¿Qué te motiva?',
          style: DS.poppins(
            size: 22,
            weight: FontWeight.w700,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        ...options.map((o) {
          final label = o['label'] as String;
          return _selectableCard(
            label: label,
            icon: o['icon'] as IconData,
            color: DS.blue,
            selected: selected == label,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _answers['q4'] = label);
            },
          );
        }),
        const SizedBox(height: 24),
        NicButton(
          text: 'CONTINUAR',
          onPressed: selected != null ? _goNext : () {},
          color: selected != null ? DS.blue : DS.cardSoft,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 6 — Q5: Rutina de aprendizaje (Screen 9)
  // ══════════════════════════════════════════════════════════════

  Widget _page6Q5Routine() {
    final selected = _answers['q5'] as String?;
    final options = [
      {'label': '5 min/día', 'sub': 'Casual', 'emoji': '\u{1F331}', 'color': DS.green},
      {'label': '10 min/día', 'sub': 'Regular', 'emoji': '\u{26A1}', 'color': DS.blue},
      {'label': '15 min/día', 'sub': 'Serio', 'emoji': '\u{1F525}', 'color': DS.orange},
      {'label': '20 min/día', 'sub': 'Intenso', 'emoji': '\u{1F680}', 'color': DS.purple},
    ];

    return _pageWrapper(
      centered: false,
      children: [
        const SizedBox(height: 12),
        Text(
          'Rutina de aprendizaje',
          style: DS.poppins(
            size: 22,
            weight: FontWeight.w700,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '¿Cuánto tiempo quieres dedicar al día?',
          style: DS.poppins(size: 14, color: DS.textSecondary),
        ),
        const SizedBox(height: 24),
        ...options.map((o) {
          final label = o['label'] as String;
          final isSelected = selected == label;
          final color = o['color'] as Color;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _answers['q5'] = label);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.08) : DS.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? color : DS.divider,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Text(o['emoji'] as String, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: DS.poppins(
                          size: 16,
                          weight: FontWeight.w600,
                          color: DS.textPrimary,
                        ),
                      ),
                      Text(
                        o['sub'] as String,
                        style: DS.poppins(size: 12, color: DS.textSecondary),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded, color: color, size: 24),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        NicButton(
          text: 'CONTINUAR',
          onPressed: selected != null ? _goNext : () {},
          color: selected != null ? DS.blue : DS.cardSoft,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 7 — Q6: Meta diaria XP (Screen 10)
  // ══════════════════════════════════════════════════════════════

  Widget _page7Q6XPGoal() {
    final selected = _answers['q6'] as String?;
    final options = ['10 XP', '20 XP', '30 XP', '50 XP'];
    final colors = [DS.green, DS.blue, DS.orange, DS.purple];

    return _pageWrapper(
      children: [
        const Spacer(flex: 2),
        Text(
          'Meta diaria de XP',
          textAlign: TextAlign.center,
          style: DS.poppins(
            size: 22,
            weight: FontWeight.w700,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Es un buen punto de partida',
          style: DS.poppins(size: 14, color: DS.textSecondary),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(options.length, (i) {
            final o = options[i];
            final isSelected = selected == o;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _answers['q6'] = o);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors[i].withValues(alpha: 0.12)
                      : DS.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? colors[i] : DS.divider,
                    width: isSelected ? 2.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    o,
                    style: DS.poppins(
                      size: 14,
                      weight: FontWeight.w700,
                      color: isSelected ? colors[i] : DS.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const Spacer(flex: 3),
        NicButton(
          text: 'CONTINUAR',
          onPressed: selected != null ? _goNext : () {},
          color: selected != null ? DS.blue : DS.cardSoft,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 8 — Q7: Recordatorio (Screen 11)
  // ══════════════════════════════════════════════════════════════

  Widget _page8Q7Reminder() {
    return _pageWrapper(
      children: [
        const Spacer(flex: 2),
        Icon(Icons.notifications_active_rounded,
            size: 64, color: DS.yellow),
        const SizedBox(height: 24),
        Text(
          '¿A qué hora quieres que te\nrecuerde practicar?',
          textAlign: TextAlign.center,
          style: DS.poppins(
            size: 20,
            weight: FontWeight.w700,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: _reminderTime,
              builder: (ctx, child) {
                return Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: DS.blue,
                      onPrimary: Colors.white,
                      surface: DS.card,
                      onSurface: DS.textPrimary,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() {
                _reminderTime = picked;
                _answers['q7_time'] = picked.format(context);
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            decoration: BoxDecoration(
              color: DS.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DS.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time_rounded, color: DS.blue, size: 28),
                const SizedBox(width: 12),
                Text(
                  _reminderTime.format(context),
                  style: DS.poppins(
                    size: 24,
                    weight: FontWeight.w700,
                    color: DS.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(flex: 3),
        NicButton(
          text: 'Activar recordatorios',
          onPressed: () {
            _answers['q7_reminder'] = true;
            _goNext();
          },
          color: DS.blue,
          icon: Icons.notifications_active_rounded,
        ),
        const SizedBox(height: 12),
        NicOutlineButton(
          text: 'Ahora no',
          onPressed: () {
            _answers['q7_reminder'] = false;
            _goNext();
          },
          color: DS.textSecondary,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 9 — Widget Prompt (Screen 12)
  // ══════════════════════════════════════════════════════════════

  Widget _page9WidgetPrompt() {
    return _pageWrapper(
      children: [
        const Spacer(flex: 2),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: DS.cyan.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.widgets_rounded, size: 40, color: DS.cyan),
        ),
        const SizedBox(height: 28),
        Text(
          'Te daré ánimos desde tu\npantalla de inicio',
          textAlign: TextAlign.center,
          style: DS.poppins(
            size: 20,
            weight: FontWeight.w700,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Agrega el widget de NIC a tu pantalla principal para recibir motivación diaria.',
          textAlign: TextAlign.center,
          style: DS.poppins(size: 14, color: DS.textSecondary),
        ),
        const Spacer(flex: 3),
        NicButton(
          text: 'Agregar widget',
          onPressed: () {
            _answers['widget'] = true;
            _goNext();
          },
          color: DS.cyan,
          icon: Icons.add_rounded,
        ),
        const SizedBox(height: 12),
        NicOutlineButton(
          text: 'Ahora no',
          onPressed: () {
            _answers['widget'] = false;
            _goNext();
          },
          color: DS.textSecondary,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 10 — Tutorial (Screen 13)
  // ══════════════════════════════════════════════════════════════

  Widget _page10Tutorial() {
    return _pageWrapper(
      children: [
        const Spacer(flex: 2),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: DS.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.phone_android_rounded,
              size: 52, color: DS.blue),
        ),
        const SizedBox(height: 32),
        Text(
          '¡Ya casi estamos!',
          textAlign: TextAlign.center,
          style: DS.poppins(
            size: 24,
            weight: FontWeight.w700,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Organiza NIC Academy en tu pantalla principal para acceder más rápido.',
          textAlign: TextAlign.center,
          style: DS.poppins(size: 15, color: DS.textSecondary, height: 1.5),
        ),
        const Spacer(flex: 3),
        NicButton(text: 'CONTINUAR', onPressed: _goNext, color: DS.blue),
        const SizedBox(height: 24),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 11 — Course Summary (Screen 14)
  // ══════════════════════════════════════════════════════════════

  Widget _page11CourseSummary() {
    final course = (_answers['q1'] as String?) ?? 'tu curso';
    final features = _courseFeaturesFor(course);

    return _pageWrapper(
      centered: false,
      children: [
        const SizedBox(height: 12),
        Text(
          'Esto encontrarás en tu curso de',
          style: DS.poppins(size: 16, color: DS.textSecondary),
        ),
        Text(
          course,
          style: DS.poppins(
            size: 24,
            weight: FontWeight.w700,
            color: DS.blue,
          ),
        ),
        const SizedBox(height: 28),
        ...List.generate(features.length, (i) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + i * 150),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(20 * (1 - value), 0),
                  child: child,
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DS.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: DS.divider),
              ),
              child: Row(
                children: [
                  Icon(
                    features[i]['icon'] as IconData,
                    color: features[i]['color'] as Color,
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      features[i]['text'] as String,
                      style: DS.poppins(
                        size: 14,
                        weight: FontWeight.w500,
                        color: DS.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        NicButton(text: 'CONTINUAR', onPressed: _goNext, color: DS.blue),
        const SizedBox(height: 24),
      ],
    );
  }

  List<Map<String, dynamic>> _courseFeaturesFor(String course) {
    switch (course) {
      case 'STEAM':
        return [
          {'icon': Icons.science, 'color': DS.blue, 'text': 'Laboratorios virtuales interactivos'},
          {'icon': Icons.code, 'color': DS.cyan, 'text': 'Programación desde cero'},
          {'icon': Icons.calculate, 'color': DS.orange, 'text': 'Matemáticas aplicadas'},
          {'icon': Icons.engineering, 'color': DS.green, 'text': 'Proyectos de ingeniería'},
        ];
      case 'Idiomas':
        return [
          {'icon': Icons.record_voice_over, 'color': DS.purple, 'text': 'Conversaciones en tiempo real'},
          {'icon': Icons.headphones, 'color': DS.blue, 'text': 'Ejercicios de escucha'},
          {'icon': Icons.menu_book, 'color': DS.orange, 'text': 'Gramática interactiva'},
          {'icon': Icons.quiz, 'color': DS.green, 'text': 'Quizzes de vocabulario'},
        ];
      default:
        return [
          {'icon': Icons.play_lesson, 'color': DS.blue, 'text': 'Lecciones interactivas'},
          {'icon': Icons.quiz, 'color': DS.purple, 'text': 'Evaluaciones prácticas'},
          {'icon': Icons.leaderboard, 'color': DS.orange, 'text': 'Ranking y gamificación'},
          {'icon': Icons.support_agent, 'color': DS.green, 'text': 'Soporte personalizado'},
        ];
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 12 — Plans (Screen 15)
  // ══════════════════════════════════════════════════════════════

  Widget _page12Plans() {
    return _pageWrapper(
      centered: false,
      children: [
        const SizedBox(height: 12),
        Text(
          'Elige tu plan',
          textAlign: TextAlign.center,
          style: DS.poppins(
            size: 24,
            weight: FontWeight.w700,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        // Premium card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: DS.purple.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DS.purple, width: 2),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.workspace_premium_rounded,
                      color: DS.purple, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    'NIC Premium',
                    style: DS.poppins(
                      size: 20,
                      weight: FontWeight.w700,
                      color: DS.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _planFeature(Icons.speed_rounded, 'Progreso rápido'),
              _planFeature(Icons.block_rounded, 'Sin anuncios'),
              _planFeature(Icons.star_rounded, 'Contenido exclusivo'),
              _planFeature(Icons.videocam_rounded, 'Clases en vivo'),
              const SizedBox(height: 20),
              NicButton(
                text: 'Empezar mi semana gratis',
                onPressed: () {
                  _answers['plan'] = 'premium';
                  _goNext();
                },
                color: DS.purple,
                icon: Icons.rocket_launch_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Free card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: DS.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DS.divider),
          ),
          child: Column(
            children: [
              Text(
                'Aprender gratis',
                style: DS.poppins(
                  size: 18,
                  weight: FontWeight.w600,
                  color: DS.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Acceso básico limitado',
                style: DS.poppins(size: 13, color: DS.textSecondary),
              ),
              const SizedBox(height: 16),
              NicOutlineButton(
                text: 'Continuar gratis',
                onPressed: () {
                  _answers['plan'] = 'free';
                  _goNext();
                },
                color: DS.textSecondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _planFeature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: DS.purple, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: DS.poppins(
              size: 14,
              weight: FontWeight.w500,
              color: DS.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 13 — First Lesson Intro (Screen 16)
  // ══════════════════════════════════════════════════════════════

  Widget _page13FirstLessonIntro() {
    return _pageWrapper(
      children: [
        const Spacer(flex: 2),
        _mascotImage(size: 140),
        const SizedBox(height: 32),
        Text(
          '¡Muy bien!\nEmpecemos con tu primera lección.',
          textAlign: TextAlign.center,
          style: DS.poppins(
            size: 20,
            weight: FontWeight.w700,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: DS.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_rounded, color: DS.blue, size: 18),
              const SizedBox(width: 6),
              Text(
                '~2 min',
                style: DS.poppins(
                  size: 14,
                  weight: FontWeight.w600,
                  color: DS.blue,
                ),
              ),
            ],
          ),
        ),
        const Spacer(flex: 3),
        NicButton(
          text: 'CONTINUAR',
          onPressed: () {
            _lessonStopwatch.start();
            _quizIndex = 0;
            _correctCount = 0;
            _selectedQuizAnswer = null;
            _quizAnswered = false;
            _goNext();
          },
          color: DS.blue,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 14 — Mini Lesson (Screen 17)
  // ══════════════════════════════════════════════════════════════

  Widget _page14MiniLesson() {
    if (_quizIndex >= _quizQuestions.length) {
      // All questions answered, auto-advance
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _lessonStopwatch.stop();
        _goNext();
      });
      return const SizedBox.shrink();
    }

    final q = _quizQuestions[_quizIndex];
    final question = q['q'] as String;
    final opts = q['opts'] as List<String>;
    final correctAnswer = q['answer'] as String;
    final progress = (_quizIndex + 1) / _quizQuestions.length;

    return _pageWrapper(
      centered: false,
      children: [
        const SizedBox(height: 8),
        // Progress bar
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: DS.cardSoft,
                  valueColor: const AlwaysStoppedAnimation(DS.blue),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Energy indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: DS.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, color: DS.orange, size: 18),
                  Text(
                    '5',
                    style: DS.poppins(
                      size: 13,
                      weight: FontWeight.w700,
                      color: DS.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text(
          question,
          style: DS.poppins(
            size: 20,
            weight: FontWeight.w700,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 28),
        ...opts.map((opt) {
          Color bgColor = DS.card;
          Color borderColor = DS.divider;
          Color textColor = DS.textPrimary;

          if (_quizAnswered && _selectedQuizAnswer != null) {
            if (opt == correctAnswer) {
              bgColor = DS.green.withValues(alpha: 0.1);
              borderColor = DS.green;
              textColor = DS.green;
            } else if (opt == _selectedQuizAnswer && opt != correctAnswer) {
              bgColor = DS.red.withValues(alpha: 0.1);
              borderColor = DS.red;
              textColor = DS.red;
            }
          } else if (_selectedQuizAnswer == opt) {
            bgColor = DS.blue.withValues(alpha: 0.08);
            borderColor = DS.blue;
          }

          return GestureDetector(
            onTap: _quizAnswered
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _selectedQuizAnswer = opt;
                      _quizAnswered = true;
                      if (opt == correctAnswer) _correctCount++;
                    });
                    // Auto advance after delay
                    Future.delayed(const Duration(milliseconds: 1500), () {
                      if (!mounted) return;
                      setState(() {
                        _quizIndex++;
                        _selectedQuizAnswer = null;
                        _quizAnswered = false;
                      });
                    });
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      opt,
                      style: DS.poppins(
                        size: 16,
                        weight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (_quizAnswered && opt == correctAnswer)
                    const Icon(Icons.check_circle_rounded,
                        color: DS.green, size: 22),
                  if (_quizAnswered &&
                      opt == _selectedQuizAnswer &&
                      opt != correctAnswer)
                    const Icon(Icons.cancel_rounded, color: DS.red, size: 22),
                ],
              ),
            ),
          );
        }),
        if (_quizAnswered) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _selectedQuizAnswer == correctAnswer
                  ? DS.green.withValues(alpha: 0.08)
                  : DS.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedQuizAnswer == correctAnswer
                      ? Icons.celebration_rounded
                      : Icons.info_outline_rounded,
                  color: _selectedQuizAnswer == correctAnswer
                      ? DS.green
                      : DS.red,
                ),
                const SizedBox(width: 12),
                Text(
                  _selectedQuizAnswer == correctAnswer
                      ? '¡Correcto!'
                      : 'Incorrecto. La respuesta es: $correctAnswer',
                  style: DS.poppins(
                    size: 14,
                    weight: FontWeight.w600,
                    color: _selectedQuizAnswer == correctAnswer
                        ? DS.green
                        : DS.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 15 — Lesson Complete (Screen 18)
  // ══════════════════════════════════════════════════════════════

  Widget _page15LessonComplete() {
    final elapsed = _lessonStopwatch.elapsed.inSeconds;
    final precision =
        _quizQuestions.isEmpty ? 100 : ((_correctCount / _quizQuestions.length) * 100).round();

    return _pageWrapper(
      children: [
        const Spacer(flex: 2),
        // Celebration
        Stack(
          alignment: Alignment.center,
          children: [
            _mascotImage(size: 120),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: DS.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: DS.bg, width: 3),
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          '¡Gran primer paso!',
          style: DS.poppins(
            size: 24,
            weight: FontWeight.w700,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 32),
        // Stats row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _statBadge('EXP', '15', DS.blue),
            _statBadge('Precisión', '$precision%', DS.green),
            _statBadge('Tiempo', '${elapsed}s', DS.orange),
          ],
        ),
        const Spacer(flex: 3),
        NicButton(
          text: 'RECIBIR EXP',
          onPressed: _goNext,
          color: DS.blue,
          icon: Icons.stars_rounded,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _statBadge(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              value,
              style: DS.poppins(
                size: 18,
                weight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: DS.poppins(size: 12, color: DS.textSecondary),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 16 — Streak (Screen 19)
  // ══════════════════════════════════════════════════════════════

  Widget _page16Streak() {
    final now = DateTime.now();
    final weekDays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    // Monday = 1, Sunday = 7
    final todayIndex = now.weekday - 1;

    return _pageWrapper(
      children: [
        const Spacer(flex: 2),
        AnimatedBuilder(
          animation: _flameCtrl,
          builder: (context, child) => Transform.scale(
            scale: _flameScale.value,
            child: child,
          ),
          child: Icon(Icons.local_fire_department_rounded,
              size: 80, color: DS.orange),
        ),
        const SizedBox(height: 24),
        Text(
          '¡Ha nacido tu racha!',
          style: DS.poppins(
            size: 24,
            weight: FontWeight.w700,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Practica cada día para formar un hábito.',
          textAlign: TextAlign.center,
          style: DS.poppins(size: 14, color: DS.textSecondary),
        ),
        const SizedBox(height: 32),
        // Week day circles
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(7, (i) {
            final isToday = i == todayIndex;
            return Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isToday ? DS.orange : DS.cardSoft,
                    border: Border.all(
                      color: isToday ? DS.orange : DS.divider,
                      width: isToday ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: isToday
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 20)
                        : null,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  weekDays[i],
                  style: DS.poppins(
                    size: 12,
                    weight: isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isToday ? DS.orange : DS.textSecondary,
                  ),
                ),
              ],
            );
          }),
        ),
        const Spacer(flex: 3),
        NicButton(text: 'CONTINUAR', onPressed: _goNext, color: DS.blue),
        const SizedBox(height: 24),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 17 — Streak Goal (Screen 20)
  // ══════════════════════════════════════════════════════════════

  Widget _page17StreakGoal() {
    final selected = _answers['streak_goal'] as String?;
    final goals = [
      {'days': '7 días', 'gems': '35 gemas \u{1F48E}'},
      {'days': '14 días', 'gems': '140 gemas \u{1F48E}'},
      {'days': '30 días', 'gems': '210 gemas \u{1F48E}'},
      {'days': '50 días', 'gems': '350 gemas \u{1F48E}'},
    ];
    final colors = [DS.green, DS.blue, DS.orange, DS.purple];

    return _pageWrapper(
      centered: false,
      children: [
        const SizedBox(height: 12),
        Text(
          '¡Comprométete a aprender!',
          textAlign: TextAlign.center,
          style: DS.poppins(
            size: 22,
            weight: FontWeight.w700,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        ...List.generate(goals.length, (i) {
          final g = goals[i];
          final isSelected = selected == g['days'];
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _answers['streak_goal'] = g['days']);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color:
                    isSelected ? colors[i].withValues(alpha: 0.08) : DS.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? colors[i] : DS.divider,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_fire_department_rounded,
                      color: colors[i], size: 28),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g['days']!,
                        style: DS.poppins(
                          size: 16,
                          weight: FontWeight.w600,
                          color: DS.textPrimary,
                        ),
                      ),
                      Text(
                        g['gems']!,
                        style: DS.poppins(size: 13, color: DS.textSecondary),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded,
                        color: colors[i], size: 24),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        NicButton(
          text: 'COMPROMETERME CON MI META',
          onPressed: selected != null ? _goNext : () {},
          color: selected != null ? DS.blue : DS.cardSoft,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 18 — Login / Register (Screen 21)
  // ══════════════════════════════════════════════════════════════

  Widget _page18Register() {
    return _pageWrapper(
      centered: false,
      children: [
        const SizedBox(height: 12),
        Text(
          'Crea tu cuenta',
          style: DS.poppins(
            size: 24,
            weight: FontWeight.w700,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Guarda tu progreso y accede desde cualquier dispositivo.',
          style: DS.poppins(size: 14, color: DS.textSecondary),
        ),
        const SizedBox(height: 28),
        _inputField(
          controller: _nameCtrl,
          label: 'Nombre',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 14),
        _inputField(
          controller: _lastNameCtrl,
          label: 'Apellido',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 14),
        _inputField(
          controller: _emailCtrl,
          label: 'Correo electrónico',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _inputField(
          controller: _passwordCtrl,
          label: 'Contraseña',
          icon: Icons.lock_outline_rounded,
          obscure: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: DS.textSecondary,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 28),
        NicButton(
          text: 'Crear cuenta',
          onPressed: _authLoading ? () {} : _handleRegister,
          color: DS.blue,
          isLoading: _authLoading,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(child: Divider(color: DS.divider)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'o continúa con',
                style: DS.poppins(size: 12, color: DS.textSecondary),
              ),
            ),
            const Expanded(child: Divider(color: DS.divider)),
          ],
        ),
        const SizedBox(height: 18),
        // Google sign-in button
        NicOutlineButton(
          text: 'Continuar con Google',
          onPressed: _authLoading ? () {} : _handleGoogleSignIn,
          color: DS.textPrimary,
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton(
            onPressed: () {
              // Skip registration, go to welcome-back page
              _goNext();
            },
            child: Text(
              'Omitir por ahora',
              style: DS.poppins(
                size: 14,
                weight: FontWeight.w500,
                color: DS.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: DS.poppins(size: 15, color: DS.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: DS.poppins(size: 14, color: DS.textSecondary),
        prefixIcon: Icon(icon, color: DS.textSecondary, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: DS.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: DS.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: DS.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: DS.blue, width: 1.5),
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor completa todos los campos',
              style: DS.poppins(size: 14, color: Colors.white)),
          backgroundColor: DS.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _authLoading = true);
    try {
      final authService = AuthService();
      await authService.login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
        context,
      );
      // If login succeeded, auth service navigates to /home.
      // Mark onboarding complete.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);
      await _persistInterests();
    } catch (_) {
      // Error handled by AuthService
    } finally {
      if (mounted) setState(() => _authLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _authLoading = true);
    try {
      final authService = AuthService();
      await authService.loginWithGoogle(context);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);
      await _persistInterests();
    } catch (_) {
      // Error handled by AuthService
    } finally {
      if (mounted) setState(() => _authLoading = false);
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE 19 — Welcome Back (Screen 22)
  // ══════════════════════════════════════════════════════════════

  Widget _page19WelcomeBack() {
    final nombre = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : 'Estudiante';

    return _pageWrapper(
      children: [
        const Spacer(flex: 2),
        _mascotImage(size: 160),
        const SizedBox(height: 32),
        Text(
          '¡Volviste $nombre!',
          textAlign: TextAlign.center,
          style: DS.poppins(
            size: 24,
            weight: FontWeight.w700,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Todo está listo para comenzar.',
          style: DS.poppins(size: 15, color: DS.textSecondary),
        ),
        const Spacer(flex: 3),
        NicButton(
          text: 'CONTINUAR',
          onPressed: _completeOnboarding,
          color: DS.blue,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
