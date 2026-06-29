import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nic_pre_u/services/horario_service.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';

enum _CalView { day, week, month }

class StudentScheduleScreen extends StatefulWidget {
  const StudentScheduleScreen({super.key});

  @override
  State<StudentScheduleScreen> createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen>
    with SingleTickerProviderStateMixin {
  final _service = HorarioService();
  late Future<HorarioEstudiante> _future;

  // weekday (1=Mon … 7=Sun) → sorted list of class maps
  Map<int, List<Map<String, dynamic>>> _schedule = {};
  List<AccesoClase> _accesos = const [];
  bool _sesionExpirada = false;

  _CalView _view = _CalView.week;
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  // ─── constants ───────────────────────────────────────────────────────────────
  static const _short = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const _months = [
    '',
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  static const _daysFull = [
    '',
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  static const _classColors = [
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
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _future = _load();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<HorarioEstudiante> _load() async {
    final h = await _service.cargar();
    if (mounted) {
      setState(() {
        _schedule = h.porDia;
        _accesos = h.accesos;
        _sesionExpirada = h.sesionExpirada;
      });
    }
    return h;
  }

  // ─── helpers ─────────────────────────────────────────────────────────────────
  bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _weekStart(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

  bool _hasClasses(DateTime d) => (_schedule[d.weekday] ?? []).isNotEmpty;

  /// ¿El horario tiene al menos una clase en toda la semana?
  bool get _hasAnyClass => _schedule.values.any((l) => l.isNotEmpty);

  List<Map<String, dynamic>> _classesFor(DateTime d) =>
      _schedule[d.weekday] ?? [];

  List<DateTime> _weekDates(DateTime d) {
    final start = _weekStart(d);
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  List<DateTime> _monthDates(DateTime d) {
    final daysInMonth = DateTime(d.year, d.month + 1, 0).day;
    return List.generate(daysInMonth, (i) => DateTime(d.year, d.month, i + 1));
  }

  DateTime _bestDateInWeek(DateTime d) {
    if (_hasClasses(d)) return d;
    final dates = _weekDates(d);
    final today = DateTime.now();
    if (dates.any((date) => _same(date, today)) && _hasClasses(today)) {
      return today;
    }
    final withClasses = dates.where(_hasClasses);
    return withClasses.isNotEmpty ? withClasses.first : d;
  }

  DateTime _bestDateInMonth(DateTime month) {
    final dates = _monthDates(month);
    final today = DateTime.now();
    if (_sameMonth(today, month) && _hasClasses(today)) return today;
    final withClasses = dates.where(_hasClasses);
    return withClasses.isNotEmpty
        ? withClasses.first
        : DateTime(month.year, month.month);
  }

  DateTime? _nextDateWithClasses(List<DateTime> dates, DateTime from) {
    final withClasses = dates.where(_hasClasses).toList()
      ..sort((a, b) => a.compareTo(b));
    if (withClasses.isEmpty) return null;
    for (final date in withClasses) {
      if (!date.isBefore(from)) return date;
    }
    return withClasses.first;
  }

  int _classCountForDates(Iterable<DateTime> dates) {
    return dates.fold<int>(
      0,
      (total, date) => total + _classesFor(date).length,
    );
  }

  String _classLabel(int count) => count == 1 ? 'clase' : 'clases';

  String _shortDate(DateTime d) => '${d.day} ${_months[d.month]}';

  void _reload() => setState(() {
    _future = _load();
  });

  void _prev() => setState(() {
    if (_view == _CalView.day) {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    } else if (_view == _CalView.week) {
      _selectedDate = _bestDateInWeek(
        _selectedDate.subtract(const Duration(days: 7)),
      );
    } else {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
      _selectedDate = _bestDateInMonth(_focusedMonth);
    }
  });

  void _next() => setState(() {
    if (_view == _CalView.day) {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    } else if (_view == _CalView.week) {
      _selectedDate = _bestDateInWeek(
        _selectedDate.add(const Duration(days: 7)),
      );
    } else {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
      _selectedDate = _bestDateInMonth(_focusedMonth);
    }
  });

  String _subtitle() {
    if (_view == _CalView.month) {
      return '${_months[_focusedMonth.month]} ${_focusedMonth.year}';
    } else if (_view == _CalView.week) {
      final ws = _weekStart(_selectedDate);
      return 'Semana del ${ws.day} ${_months[ws.month]}';
    } else {
      return '${_daysFull[_selectedDate.weekday]}, '
          '${_selectedDate.day} de ${_months[_selectedDate.month]}';
    }
  }

  // ─── build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: DS.bg,
        body: FutureBuilder<HorarioEstudiante>(
          future: _future,
          builder: (context, snap) {
            final loading = snap.connectionState == ConnectionState.waiting;
            return Column(
              children: [
                _Header(
                  subtitle: _subtitle(),
                  onBack: () => Navigator.pop(context),
                  onPrev: _prev,
                  onNext: _next,
                ),
                _ViewToggle(
                  current: _view,
                  onChanged: (v) {
                    setState(() {
                      _view = v;
                      if (v == _CalView.week) {
                        _selectedDate = _bestDateInWeek(_selectedDate);
                      }
                      if (v == _CalView.month) {
                        _focusedMonth = DateTime(
                          _selectedDate.year,
                          _selectedDate.month,
                        );
                        _selectedDate = _bestDateInMonth(_focusedMonth);
                      }
                    });
                    _fadeCtrl.reset();
                    _fadeCtrl.forward();
                  },
                ),
                // Calendar section
                if (!loading) ...[
                  if (_view == _CalView.week) _buildWeekRow(),
                  if (_view == _CalView.month) _buildMonthGrid(),
                  if (_view == _CalView.day) _buildDayStrip(),
                ],
                const _Divider(),
                if (!loading && _accesos.isNotEmpty) _buildAccesos(),
                // Class list
                Expanded(
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: DS.purple,
                            strokeWidth: 2,
                          ),
                        )
                      : FadeTransition(
                          opacity: _fade,
                          child: _sesionExpirada
                              ? _buildSessionExpired()
                              : _buildScheduleBody(),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── accesos (Zoom / WhatsApp) ────────────────────────────────────────────────
  Future<void> _abrir(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildAccesos() {
    final zoomLinks = _accesos
        .where((a) => (a.virtualLink ?? '').isNotEmpty)
        .toList();
    final waLinks = _accesos.expand((a) => a.whatsapps).toSet().toList();
    if (zoomLinks.isEmpty && waLinks.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          for (final a in zoomLinks)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _AccesoChip(
                icon: Icons.videocam_rounded,
                label: 'Clase virtual',
                color: DS.blue,
                onTap: () => _abrir(a.virtualLink!),
              ),
            ),
          for (final wa in waLinks)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _AccesoChip(
                icon: Icons.chat_rounded,
                label: 'Grupo WhatsApp',
                color: DS.green,
                onTap: () => _abrir(wa),
              ),
            ),
        ],
      ),
    );
  }

  // ─── week row ────────────────────────────────────────────────────────────────
  Widget _buildWeekRow() {
    final start = _weekStart(_selectedDate);
    final today = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: List.generate(7, (i) {
          final date = start.add(Duration(days: i));
          final isSel = _same(date, _selectedDate);
          final isToday = _same(date, today);
          final hasCls = _hasClasses(date);
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDate = date),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSel
                      ? DS.purple
                      : isToday
                      ? DS.purple.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: isToday && !isSel
                      ? Border.all(
                          color: DS.purple.withValues(alpha: 0.45),
                          width: 1.5,
                        )
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _short[i],
                      style: DS.poppins(
                        size: 10,
                        weight: FontWeight.w600,
                        color: isSel ? Colors.white70 : DS.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${date.day}',
                      style: DS.poppins(
                        size: 16,
                        weight: FontWeight.w800,
                        color: isSel
                            ? Colors.white
                            : isToday
                            ? DS.purple
                            : DS.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasCls
                            ? (isSel
                                  ? Colors.white.withValues(alpha: 0.75)
                                  : DS.purple)
                            : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── month grid ──────────────────────────────────────────────────────────────
  Widget _buildMonthGrid() {
    final first = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final offset = first.weekday - 1; // Mon=0
    final daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        children: [
          // Day-of-week headers
          Row(
            children: _short
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: DS.poppins(
                          size: 11,
                          weight: FontWeight.w600,
                          color: DS.textSecondary,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          // Date cells
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.05,
            ),
            itemCount: offset + daysInMonth,
            itemBuilder: (_, idx) {
              if (idx < offset) return const SizedBox.shrink();
              final day = idx - offset + 1;
              final date = DateTime(
                _focusedMonth.year,
                _focusedMonth.month,
                day,
              );
              final isSel = _same(date, _selectedDate);
              final isToday = _same(date, today);
              final hasCls = _hasClasses(date);
              return GestureDetector(
                onTap: () => setState(() => _selectedDate = date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSel
                        ? DS.purple
                        : isToday
                        ? DS.purple.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: isToday && !isSel
                        ? Border.all(
                            color: DS.purple.withValues(alpha: 0.5),
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$day',
                        style: DS.poppins(
                          size: 13,
                          weight: isSel || isToday
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isSel
                              ? Colors.white
                              : isToday
                              ? DS.purple
                              : DS.textPrimary,
                        ),
                      ),
                      if (hasCls)
                        Positioned(
                          bottom: 3,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSel
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : DS.purple,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── day strip ───────────────────────────────────────────────────────────────
  Widget _buildDayStrip() {
    final today = DateTime.now();
    final start = _selectedDate.subtract(const Duration(days: 3));
    return SizedBox(
      height: 78,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: List.generate(7, (i) {
            final date = start.add(Duration(days: i));
            final isSel = _same(date, _selectedDate);
            final isToday = _same(date, today);
            final hasCls = _hasClasses(date);
            final wd = date.weekday - 1;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedDate = date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isSel
                        ? DS.purple
                        : isToday
                        ? DS.purple.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: isToday && !isSel
                        ? Border.all(
                            color: DS.purple.withValues(alpha: 0.4),
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _short[wd],
                        style: DS.poppins(
                          size: 10,
                          weight: FontWeight.w600,
                          color: isSel ? Colors.white70 : DS.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${date.day}',
                        style: DS.poppins(
                          size: 15,
                          weight: FontWeight.w800,
                          color: isSel
                              ? Colors.white
                              : isToday
                              ? DS.purple
                              : DS.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasCls
                              ? (isSel ? Colors.white70 : DS.purple)
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─── class list (timeline with fixed hour slots) ─────────────────────────────
  Widget _buildClassList() {
    final classes = _classesFor(_selectedDate);

    // Build a map: hour (int) → list of classes starting that hour
    final Map<int, List<Map<String, dynamic>>> byHour = {};
    int colorIdx = 0;
    final Map<Map<String, dynamic>, Color> classColor = {};
    for (final c in classes) {
      final t = (c['Hora inicio'] ?? '').toString();
      final h = int.tryParse(t.split(':').first) ?? -1;
      if (h >= 0) {
        byHour.putIfAbsent(h, () => []);
        byHour[h]!.add(c);
      }
      classColor[c] = _classColors[colorIdx % _classColors.length];
      colorIdx++;
    }

    const startH = 7;
    const endH = 21;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      itemCount: endH - startH + 1,
      itemBuilder: (_, i) {
        final hour = startH + i;
        final label = '${hour.toString().padLeft(2, '0')}:00';
        final slot = byHour[hour] ?? [];
        final isLast = hour == endH;

        return _HourRow(
          label: label,
          classes: slot,
          classColors: slot.map((c) => classColor[c] ?? DS.purple).toList(),
          isLast: isLast,
        );
      },
    );
  }

  Widget _buildScheduleBody() {
    if (!_hasAnyClass) return _buildEmptyState();

    switch (_view) {
      case _CalView.day:
        return _buildClassList();
      case _CalView.week:
        return _buildWeekAgenda();
      case _CalView.month:
        return _buildMonthAgenda();
    }
  }

  Widget _buildWeekAgenda() {
    final dates = _weekDates(_selectedDate);
    final datesWithClasses = dates.where(_hasClasses).toList();
    final totalClasses = _classCountForDates(datesWithClasses);

    if (datesWithClasses.isEmpty) {
      return _buildRangeEmptyState(
        icon: Icons.calendar_view_week_rounded,
        title: 'Sin clases esta semana',
        message: 'No hay clases programadas para esta semana.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      children: [
        _buildDateRail(
          title: 'Días con clase',
          dates: datesWithClasses,
          totalClasses: totalClasses,
          color: DS.purple,
        ),
        const SizedBox(height: 18),
        _buildSelectedDayAgenda(
          date: _selectedDate,
          classes: _classesFor(_selectedDate),
          fallbackDates: datesWithClasses,
          colorOffset: _selectedDate.weekday - 1,
          emptyMessage: 'Toca un día con punto morado para ver sus clases.',
        ),
      ],
    );
  }

  Widget _buildMonthAgenda() {
    final dates = _monthDates(_focusedMonth);
    final datesWithClasses = dates.where(_hasClasses).toList();
    final totalClasses = _classCountForDates(datesWithClasses);
    final activeDate = _sameMonth(_selectedDate, _focusedMonth)
        ? _selectedDate
        : datesWithClasses.first;

    if (datesWithClasses.isEmpty) {
      return _buildRangeEmptyState(
        icon: Icons.calendar_month_rounded,
        title: 'Sin clases este mes',
        message: 'No hay clases programadas para este mes.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      children: [
        _buildDateRail(
          title: 'Días con clase en ${_months[_focusedMonth.month]}',
          dates: datesWithClasses,
          totalClasses: totalClasses,
          color: DS.blue,
        ),
        const SizedBox(height: 18),
        _buildSelectedDayAgenda(
          date: activeDate,
          classes: _classesFor(activeDate),
          fallbackDates: datesWithClasses,
          colorOffset: activeDate.day % _classColors.length,
          emptyMessage: 'Selecciona un día marcado en el calendario.',
        ),
      ],
    );
  }

  Widget _buildDateRail({
    required String title,
    required List<DateTime> dates,
    required int totalClasses,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: DS.poppins(
                  size: 14,
                  weight: FontWeight.w800,
                  color: DS.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color.withValues(alpha: 0.24)),
              ),
              child: Text(
                '$totalClasses ${_classLabel(totalClasses)}',
                style: DS.poppins(
                  size: 10,
                  weight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: dates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) =>
                _buildDateRailItem(date: dates[i], color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRailItem({required DateTime date, required Color color}) {
    final active = _same(date, _selectedDate);
    final count = _classesFor(date).length;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedDate = date;
          if (_view == _CalView.month) {
            _focusedMonth = DateTime(date.year, date.month);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 78,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active ? color : DS.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? color : const Color(0xFF2A2A3C)),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _short[date.weekday - 1],
              style: DS.poppins(
                size: 10,
                weight: FontWeight.w800,
                color: active ? Colors.white70 : DS.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '${date.day}',
              style: DS.poppins(
                size: 20,
                weight: FontWeight.w900,
                color: active ? Colors.white : DS.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$count ${_classLabel(count)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DS.poppins(
                size: 9,
                weight: FontWeight.w700,
                color: active ? Colors.white70 : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDayAgenda({
    required DateTime date,
    required List<Map<String, dynamic>> classes,
    required List<DateTime> fallbackDates,
    required int colorOffset,
    required String emptyMessage,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Column(
        key: ValueKey('agenda-${date.year}-${date.month}-${date.day}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSelectedDayHeader(date: date, classes: classes),
          const SizedBox(height: 12),
          if (classes.isEmpty)
            _buildInlineDayEmpty(
              datesWithClasses: fallbackDates,
              selectedDate: date,
              message: emptyMessage,
            )
          else
            for (final entry in classes.asMap().entries) ...[
              _ClassCard(
                clase: entry.value,
                color:
                    _classColors[(colorOffset + entry.key) %
                        _classColors.length],
              ),
              if (entry.key < classes.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _buildSelectedDayHeader({
    required DateTime date,
    required List<Map<String, dynamic>> classes,
  }) {
    final today = DateTime.now();
    final isToday = _same(date, today);
    final count = classes.length;
    final firstHour = count == 0
        ? ''
        : (classes.first['Hora inicio'] ?? '').toString();
    final lastHour = count == 0
        ? ''
        : (classes.last['Hora fin'] ?? '').toString();
    final range = firstHour.isNotEmpty && lastHour.isNotEmpty
        ? '$firstHour – $lastHour'
        : count == 0
        ? 'Sin clases programadas'
        : '$count ${_classLabel(count)} programadas';

    return Row(
      children: [
        Container(
          width: 52,
          height: 58,
          decoration: BoxDecoration(
            color: isToday
                ? DS.purple.withValues(alpha: 0.16)
                : const Color(0xFF1C1C2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isToday
                  ? DS.purple.withValues(alpha: 0.38)
                  : const Color(0xFF2A2A3C),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _short[date.weekday - 1],
                style: DS.poppins(
                  size: 10,
                  weight: FontWeight.w800,
                  color: isToday ? DS.purple : DS.textSecondary,
                ),
              ),
              Text(
                '${date.day}',
                style: DS.poppins(
                  size: 19,
                  weight: FontWeight.w900,
                  color: DS.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isToday
                    ? 'Hoy, ${_daysFull[date.weekday]}'
                    : _daysFull[date.weekday],
                style: DS.poppins(
                  size: 16,
                  weight: FontWeight.w900,
                  color: DS.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_shortDate(date)} · $range',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DS.poppins(
                  size: 11,
                  weight: FontWeight.w500,
                  color: DS.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: DS.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: DS.poppins(
                size: 12,
                weight: FontWeight.w900,
                color: DS.purple,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInlineDayEmpty({
    required List<DateTime> datesWithClasses,
    required DateTime selectedDate,
    required String message,
  }) {
    final nextDate = _nextDateWithClasses(datesWithClasses, selectedDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: DS.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A3C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: DS.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: DS.purple,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sin clases este día',
                  style: DS.poppins(
                    size: 14,
                    weight: FontWeight.w800,
                    color: DS.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: DS.poppins(
              size: 12,
              weight: FontWeight.w500,
              color: DS.textSecondary,
              height: 1.35,
            ),
          ),
          if (nextDate != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedDate = nextDate);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                backgroundColor: DS.purple.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: DS.purple,
              ),
              label: Text(
                'Ver ${_shortDate(nextDate)}',
                style: DS.poppins(
                  size: 12,
                  weight: FontWeight.w800,
                  color: DS.purple,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRangeEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: DS.purple.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: DS.purple.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Icon(icon, size: 42, color: DS.purple),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: DS.poppins(
                size: 18,
                weight: FontWeight.w800,
                color: DS.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: DS.poppins(size: 13, color: DS.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  // ─── sesión expirada (token 401 — single-session reemplazada) ─────────────────
  Widget _buildSessionExpired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: DS.orange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: DS.orange.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.lock_clock_rounded,
                size: 42,
                color: DS.orange,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Tu sesión expiró',
              textAlign: TextAlign.center,
              style: DS.poppins(
                size: 18,
                weight: FontWeight.w800,
                color: DS.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Iniciaste sesión en otro dispositivo o en la web. Vuelve a '
              'iniciar sesión para ver tu horario actualizado.',
              textAlign: TextAlign.center,
              style: DS.poppins(size: 13, color: DS.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DS.purple,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: Text(
                'Iniciar sesión',
                style: DS.poppins(
                  size: 14,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── empty state (sin clases en el horario) ───────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: DS.purple.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: DS.purple.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.event_busy_rounded,
                size: 42,
                color: DS.purple,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Aún no tienes horario',
              textAlign: TextAlign.center,
              style: DS.poppins(
                size: 18,
                weight: FontWeight.w800,
                color: DS.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando tu academia publique tu horario de clases, aparecerá aquí automáticamente.',
              textAlign: TextAlign.center,
              style: DS.poppins(size: 13, color: DS.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _reload,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                backgroundColor: DS.purple.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(
                Icons.refresh_rounded,
                size: 18,
                color: DS.purple,
              ),
              label: Text(
                'Reintentar',
                style: DS.poppins(
                  size: 13,
                  weight: FontWeight.w700,
                  color: DS.purple,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _Header({
    required this.subtitle,
    required this.onBack,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 4,
        right: 4,
        bottom: 10,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF141422),
        border: Border(bottom: BorderSide(color: Color(0xFF252535))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_rounded,
              color: Colors.white,
              size: 20,
            ),
            padding: const EdgeInsets.all(8),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mi Horario',
                  style: DS.poppins(
                    size: 19,
                    weight: FontWeight.w800,
                    color: DS.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: DS.poppins(size: 11, color: DS.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onPrev,
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: Colors.white70,
              size: 26,
            ),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white70,
              size: 26,
            ),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}

// ─── View toggle ─────────────────────────────────────────────────────────────
class _ViewToggle extends StatelessWidget {
  final _CalView current;
  final ValueChanged<_CalView> onChanged;

  const _ViewToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFF252535)),
        ),
        child: Row(
          children: [
            _ToggleBtn(
              label: 'Día',
              active: current == _CalView.day,
              onTap: () => onChanged(_CalView.day),
            ),
            _ToggleBtn(
              label: 'Semana',
              active: current == _CalView.week,
              onTap: () => onChanged(_CalView.week),
            ),
            _ToggleBtn(
              label: 'Mes',
              active: current == _CalView.month,
              onTap: () => onChanged(_CalView.month),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleBtn({
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
          decoration: BoxDecoration(
            color: active ? DS.purple : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: DS.purple.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: DS.poppins(
              size: 12,
              weight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? Colors.white : DS.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Divider ─────────────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: const Color(0xFF252535));
  }
}

// ─── Hour row: time marker + optional class cards ─────────────────────────────
class _HourRow extends StatelessWidget {
  final String label;
  final List<Map<String, dynamic>> classes;
  final List<Color> classColors;
  final bool isLast;

  const _HourRow({
    required this.label,
    required this.classes,
    required this.classColors,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasClass = classes.isNotEmpty;
    final accentColor = hasClass ? classColors.first : const Color(0xFF252535);

    return Container(
      // Highlighted background when there's a class
      decoration: hasClass
          ? BoxDecoration(
              color: accentColor.withValues(alpha: 0.06),
              border: Border(left: BorderSide(color: accentColor, width: 3)),
            )
          : null,
      margin: hasClass ? const EdgeInsets.only(bottom: 4) : EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hour label ──
            SizedBox(
              width: 58,
              child: Padding(
                padding: const EdgeInsets.only(top: 14, right: 4),
                child: Text(
                  label,
                  textAlign: TextAlign.right,
                  style: DS.poppins(
                    size: hasClass ? 13 : 11,
                    weight: hasClass ? FontWeight.w800 : FontWeight.w400,
                    color: hasClass
                        ? accentColor
                        : DS.textSecondary.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
            // ── Timeline spine ──
            SizedBox(
              width: 22,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // dot
                  Container(
                    width: hasClass ? 13 : 7,
                    height: hasClass ? 13 : 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasClass ? accentColor : const Color(0xFF1E1E2E),
                      border: Border.all(
                        color: hasClass
                            ? accentColor.withValues(alpha: 0.8)
                            : const Color(0xFF303045),
                        width: hasClass ? 2 : 1,
                      ),
                      boxShadow: hasClass
                          ? [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.6),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  // vertical connector line
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: hasClass
                                ? [
                                    accentColor.withValues(alpha: 0.4),
                                    accentColor.withValues(alpha: 0.05),
                                  ]
                                : [
                                    const Color(0xFF252535),
                                    const Color(0xFF1A1A28),
                                  ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ── Content ──
            Expanded(
              child: hasClass
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: classes.asMap().entries.map((e) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: e.key < classes.length - 1 ? 10 : 0,
                            ),
                            child: _ClassCard(
                              clase: e.value,
                              color: classColors[e.key % classColors.length],
                            ),
                          );
                        }).toList(),
                      ),
                    )
                  // Empty slot — just a taller spacer with a subtle dash line
                  : SizedBox(
                      height: 52,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8, right: 16),
                          child: Row(
                            children: List.generate(
                              18,
                              (i) => Expanded(
                                child: Container(
                                  height: 1,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  color: i.isEven
                                      ? const Color(0xFF1E1E2E)
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                          ),
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

// ─── Class card ───────────────────────────────────────────────────────────────
class _ClassCard extends StatelessWidget {
  final Map<String, dynamic> clase;
  final Color color;

  const _ClassCard({required this.clase, required this.color});

  @override
  Widget build(BuildContext context) {
    final inicio = (clase['Hora inicio'] ?? '').toString();
    final fin = (clase['Hora fin'] ?? '').toString();
    final materia = (clase['Materia'] ?? clase['_cursoNombre'] ?? '')
        .toString();
    final aula = (clase['Aula'] ?? '').toString();
    final profesor = (clase['Profesor'] ?? '').toString();
    final modalidad = (clase['Modalidad'] ?? '').toString();
    final paralelo = (clase['Paralelo'] ?? '').toString();
    final universidad = (clase['Universidad'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: DS.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Color accent line + time badge
          Row(
            children: [
              Container(
                height: 3,
                width: 32,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Spacer(),
              if (inicio.isNotEmpty)
                Text(
                  '$inicio${fin.isNotEmpty ? ' – $fin' : ''}',
                  style: DS.poppins(
                    size: 10,
                    weight: FontWeight.w600,
                    color: color,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            materia,
            style: DS.poppins(
              size: 14,
              weight: FontWeight.w700,
              color: DS.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (aula.isNotEmpty)
                _Chip(
                  icon: Icons.room_rounded,
                  label: 'Aula $aula',
                  color: color,
                ),
              if (modalidad.isNotEmpty)
                _Chip(
                  icon: Icons.laptop_rounded,
                  label: modalidad,
                  color: color,
                ),
              if (paralelo.isNotEmpty)
                _Chip(
                  icon: Icons.groups_rounded,
                  label: 'Paralelo $paralelo',
                  color: color,
                ),
              if (universidad.isNotEmpty)
                _Chip(
                  icon: Icons.school_rounded,
                  label: universidad,
                  color: color,
                ),
            ],
          ),
          if (profesor.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_rounded, size: 13, color: DS.textSecondary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    profesor,
                    style: DS.poppins(size: 12, color: DS.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AccesoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AccesoChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: DS.poppins(
                  size: 12,
                  weight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DS.poppins(
                size: 10,
                weight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
