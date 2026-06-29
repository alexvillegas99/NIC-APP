import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:nic_pre_u/services/simulador_service.dart';
import 'package:nic_pre_u/services/last_activity_service.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';
import 'package:nic_pre_u/screens/simuladores/sim_html.dart';
import 'package:nic_pre_u/screens/simuladores/sim_review_screen.dart';

enum _Phase { intro, exam }

/// Pantalla de ejecución del simulador: intro (modo + historial + ESPOCH) → examen.
class SimuladorRunScreen extends StatefulWidget {
  final SimCatalogItem item;
  const SimuladorRunScreen({super.key, required this.item});

  @override
  State<SimuladorRunScreen> createState() => _SimuladorRunScreenState();
}

class _SimuladorRunScreenState extends State<SimuladorRunScreen> {
  final _service = SimuladorService();

  _Phase _phase = _Phase.intro;
  String _mode = 'examen'; // examen | entrenamiento
  bool _starting = false;

  // datos del examen
  SimDraw? _draw;
  late List<String?> _answers;
  final Set<int> _locked = {}; // entrenamiento: preguntas ya bloqueadas
  int _current = 0;

  // timer
  Timer? _timer;
  DateTime? _endAt;
  Duration _remaining = Duration.zero;
  DateTime? _startedAt;

  // historial
  late Future<SimHistory> _history;

  // ESPOCH
  bool _loadingEspoch = false;
  List<_EspochCampo> _campos = [];
  _EspochCampo? _campoSel;
  _EspochCarrera? _carreraSel;

  Color get _color => simColor(widget.item.color);
  Color get _accent => simColor(widget.item.accent, fallback: _color);

  @override
  void initState() {
    super.initState();
    _history = _service.history(widget.item.id);
    if (widget.item.esEspoch) _loadEspoch();
    // Recuerda este simulador como "última actividad" para el home.
    final it = widget.item;
    final ciudad = it.ciudad.trim();
    LastActivityService().recordSimulador(
      title: it.nombre,
      subtitle: ciudad.isEmpty ? it.uni : '${it.uni} · $ciudad',
      sim: it.toJson(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadEspoch() async {
    setState(() => _loadingEspoch = true);
    try {
      final data = await _service.espochCarreras();
      _campos = _parseEspoch(data);
    } catch (_) {}
    if (mounted) setState(() => _loadingEspoch = false);
  }

  List<_EspochCampo> _parseEspoch(Map<String, dynamic> data) {
    final out = <_EspochCampo>[];
    final porCampo = data['porCampo'];
    List<_EspochCarrera> careersFrom(dynamic raw) {
      final list = (raw as List?) ?? const [];
      return list.whereType<Map>().map((m) {
        return _EspochCarrera(
          id: (m['id'] ?? '').toString(),
          name: (m['name'] ?? m['nombre'] ?? '').toString(),
          faculty: (m['faculty'] ?? m['facultad'] ?? '').toString(),
        );
      }).where((c) => c.id.isNotEmpty).toList();
    }

    if (porCampo is List) {
      for (final c in porCampo.whereType<Map>()) {
        out.add(_EspochCampo(
          label: (c['fieldName'] ?? c['nombre'] ?? c['fieldId'] ?? '')
              .toString(),
          carreras: careersFrom(c['careers'] ?? c['carreras']),
        ));
      }
    } else if (porCampo is Map) {
      porCampo.forEach((k, v) {
        if (v is Map) {
          out.add(_EspochCampo(
            label: (v['nombre'] ?? v['fieldName'] ?? k).toString(),
            carreras: careersFrom(v['carreras'] ?? v['careers']),
          ));
        }
      });
    }
    return out.where((c) => c.carreras.isNotEmpty).toList();
  }

  // ── iniciar ──────────────────────────────────────────────────────────────────
  Future<void> _start() async {
    if (_starting) return;
    if (widget.item.esEspoch && _carreraSel == null) {
      _snack('Elige tu carrera primero', DS.warning);
      return;
    }
    setState(() => _starting = true);
    HapticFeedback.mediumImpact();
    try {
      final draw = await _service.draw(
        testType: widget.item.id,
        careerId: widget.item.esEspoch ? _carreraSel?.id : null,
      );
      if (draw.questions.isEmpty) {
        _snack('Este simulador no tiene preguntas todavía', DS.warning);
        return;
      }
      setState(() {
        _draw = draw;
        _answers = List<String?>.filled(draw.questions.length, null);
        _current = 0;
        _locked.clear();
        _phase = _Phase.exam;
        _startedAt = DateTime.now();
      });
      _startTimer(draw.sim.totalMin);
    } on SinIntentosException {
      _showSinIntentos();
    } catch (e) {
      _snack('No se pudo iniciar: $e', DS.error);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _startTimer(int minutes) {
    _endAt = DateTime.now().add(Duration(minutes: minutes <= 0 ? 60 : minutes));
    _remaining = _endAt!.difference(DateTime.now());
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final rem = _endAt!.difference(DateTime.now());
      if (rem.isNegative) {
        _timer?.cancel();
        _submit(timedOut: true);
        return;
      }
      if (mounted) setState(() => _remaining = rem);
    });
  }

  // ── responder ──────────────────────────────────────────────────────────────
  void _answer(String letra) {
    if (_mode == 'entrenamiento' && _locked.contains(_current)) return;
    setState(() {
      _answers[_current] = letra;
      if (_mode == 'entrenamiento') _locked.add(_current);
    });
    final q = _draw!.questions[_current];
    if (_mode == 'entrenamiento') {
      final ok = letra == q.correct;
      HapticFeedback.lightImpact();
      _snack(
        ok ? '¡Correcto!' : 'Incorrecto · la correcta era ${q.correct}',
        ok ? DS.success : DS.error,
        short: true,
      );
    }
  }

  void _goto(int i) {
    if (i < 0 || i >= _draw!.questions.length) return;
    setState(() => _current = i);
  }

  // ── finalizar ────────────────────────────────────────────────────────────────
  Future<void> _confirmFinish() async {
    final pendientes = _answers.where((a) => a == null).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: DS.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('¿Finalizar simulador?',
            style: DS.poppins(
                size: 17, weight: FontWeight.w700, color: DS.textPrimary)),
        content: Text(
          pendientes == 0
              ? 'Respondiste todas las preguntas. Se calculará tu resultado.'
              : 'Te quedan $pendientes preguntas sin responder. ¿Seguro que quieres finalizar?',
          style: DS.poppins(size: 13, color: DS.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Seguir',
                style: DS.poppins(size: 13, color: DS.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _color, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Finalizar',
                style: DS.poppins(size: 13, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok == true) _submit();
  }

  Future<void> _submit({bool timedOut = false}) async {
    _timer?.cancel();
    final draw = _draw!;
    final dur = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inSeconds;
    final answersPayload = [
      for (var i = 0; i < draw.questions.length; i++)
        {'questionId': draw.questions[i].id, 'selected': _answers[i]},
    ];

    _showLoading();
    try {
      final result = await _service.submit(
        attemptId: draw.attemptId,
        answers: answersPayload,
        durationSeconds: dur,
        mode: _mode,
        timedOut: timedOut,
      );
      if (!mounted) return;
      Navigator.pop(context); // cierra loading
      final review = SimReview(
        attemptId: draw.attemptId,
        sim: draw.sim,
        questions: draw.questions,
        result: result,
        answers: List<String?>.from(_answers),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SimReviewScreen(review: review, justFinished: true),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _snack('No se pudo enviar: $e', DS.error);
        _startTimer(1); // re-permite reintento mínimo
      }
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: DS.bg,
        body: SafeArea(
          child: _phase == _Phase.intro ? _buildIntro() : _buildExam(),
        ),
      ),
    );
  }

  // ── INTRO ──────────────────────────────────────────────────────────────────
  Widget _buildIntro() {
    final it = widget.item;
    return Column(
      children: [
        _introHeader(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
            children: [
              // stats
              Row(
                children: [
                  _statBox('${it.totalPreguntas}', 'Preguntas', _color),
                  const SizedBox(width: 10),
                  _statBox('${it.totalMin}', 'Minutos', _accent),
                  const SizedBox(width: 10),
                  _statBox('${it.secciones.length}', 'Secciones', DS.purple),
                ],
              ),
              const SizedBox(height: 18),
              // ESPOCH career picker
              if (it.esEspoch) ...[
                _sectionTitle('Tu carrera'),
                const SizedBox(height: 8),
                _espochPicker(),
                const SizedBox(height: 18),
              ],
              // secciones
              if (it.secciones.isNotEmpty) ...[
                _sectionTitle('Secciones'),
                const SizedBox(height: 8),
                ...it.secciones.map(_seccionTile),
                const SizedBox(height: 18),
              ],
              // modo
              _sectionTitle('Modo'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _modeBtn(
                    value: 'examen',
                    icon: Icons.flag_rounded,
                    title: 'Examen',
                    desc: 'Como el real',
                  ),
                  const SizedBox(width: 10),
                  _modeBtn(
                    value: 'entrenamiento',
                    icon: Icons.school_rounded,
                    title: 'Entrenamiento',
                    desc: 'Feedback al instante',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // historial
              _historial(),
            ],
          ),
        ),
        _startBar(),
      ],
    );
  }

  Widget _introHeader() {
    final it = widget.item;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_color.withValues(alpha: 0.30), DS.bg],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _color.withValues(alpha: 0.5)),
            ),
            alignment: Alignment.center,
            child: Text(it.glyph,
                style: DS.poppins(
                    size: 18, weight: FontWeight.w800, color: _color)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Examen ${it.uni}',
                    style: DS.poppins(
                        size: 17,
                        weight: FontWeight.w800,
                        color: DS.textPrimary)),
                Text(it.nombre,
                    style: DS.poppins(size: 11, color: DS.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: DS.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(value,
                style: DS.poppins(
                    size: 22, weight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: DS.poppins(size: 11, color: DS.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style:
          DS.poppins(size: 14, weight: FontWeight.w700, color: DS.textPrimary));

  Widget _seccionTile(SimSeccion s) {
    final c = simColor(s.color, fallback: _color);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DS.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DS.divider),
      ),
      child: Row(
        children: [
          Text(s.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(s.nombre,
                style: DS.poppins(
                    size: 13,
                    weight: FontWeight.w600,
                    color: DS.textPrimary)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${s.count}',
                style: DS.poppins(
                    size: 11, weight: FontWeight.w700, color: c)),
          ),
        ],
      ),
    );
  }

  Widget _modeBtn({
    required String value,
    required IconData icon,
    required String title,
    required String desc,
  }) {
    final active = _mode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _mode = value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active ? _color.withValues(alpha: 0.18) : DS.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: active ? _color : DS.divider,
                width: active ? 1.6 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: active ? _color : DS.textSecondary, size: 22),
              const SizedBox(height: 8),
              Text(title,
                  style: DS.poppins(
                      size: 13,
                      weight: FontWeight.w700,
                      color: DS.textPrimary)),
              const SizedBox(height: 2),
              Text(desc,
                  style: DS.poppins(size: 10, color: DS.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _espochPicker() {
    if (_loadingEspoch) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(
            child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: DS.purple, strokeWidth: 2))),
      );
    }
    if (_campos.isEmpty) {
      return Text('No se pudieron cargar las carreras. Intenta de nuevo.',
          style: DS.poppins(size: 12, color: DS.textSecondary));
    }
    return Column(
      children: [
        _dropdown<_EspochCampo>(
          hint: 'Campo amplio',
          value: _campoSel,
          items: _campos,
          label: (c) => c.label,
          onChanged: (c) => setState(() {
            _campoSel = c;
            _carreraSel = null;
          }),
        ),
        const SizedBox(height: 10),
        _dropdown<_EspochCarrera>(
          hint: 'Carrera',
          value: _carreraSel,
          items: _campoSel?.carreras ?? const [],
          label: (c) => c.name,
          onChanged: (c) => setState(() => _carreraSel = c),
        ),
      ],
    );
  }

  Widget _dropdown<T>({
    required String hint,
    required T? value,
    required List<T> items,
    required String Function(T) label,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: DS.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DS.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: DS.card,
          hint: Text(hint,
              style: DS.poppins(size: 13, color: DS.textSecondary)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: DS.textSecondary),
          items: items
              .map((e) => DropdownMenuItem<T>(
                    value: e,
                    child: Text(label(e),
                        style: DS.poppins(size: 13, color: DS.textPrimary),
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _historial() {
    return FutureBuilder<SimHistory>(
      future: _history,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final h = snap.data;
        if (h == null || h.vacio) return const SizedBox.shrink();
        final items = [...h.examen, ...h.entrenamiento]
          ..sort((a, b) => (b.finishedAt ?? '').compareTo(a.finishedAt ?? ''));
        final top = items.take(5).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Tus intentos'),
            const SizedBox(height: 8),
            ...top.map(_historialTile),
          ],
        );
      },
    );
  }

  Widget _historialTile(SimHistoryItem h) {
    final pct = h.scorePct.round();
    final color = pct >= 70
        ? DS.success
        : pct >= 50
            ? DS.warning
            : DS.error;
    String fecha = '';
    if (h.finishedAt != null) {
      final d = DateTime.tryParse(h.finishedAt!);
      if (d != null) fecha = DateFormat('d MMM, HH:mm', 'es').format(d.toLocal());
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DS.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DS.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text('$pct%',
                style: DS.poppins(
                    size: 15, weight: FontWeight.w800, color: color)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      h.mode == 'examen' ? 'Examen' : 'Entrenamiento',
                      style: DS.poppins(
                          size: 12,
                          weight: FontWeight.w600,
                          color: DS.textPrimary),
                    ),
                    const SizedBox(width: 6),
                    if (h.isBest) _miniBadge('MEJOR', DS.success),
                    if (h.timedOut) _miniBadge('TIEMPO', DS.warning),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${h.correctCount}/${h.totalQuestions} aciertos${fecha.isNotEmpty ? ' · $fecha' : ''}',
                  style: DS.poppins(size: 10, color: DS.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _verIntento(h.id),
            child: Text('Ver',
                style: DS.poppins(
                    size: 12, weight: FontWeight.w600, color: _color)),
          ),
        ],
      ),
    );
  }

  Widget _miniBadge(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(t,
            style:
                DS.poppins(size: 7, weight: FontWeight.w700, color: c)),
      );

  Future<void> _verIntento(dynamic attemptId) async {
    _showLoading();
    try {
      final review = await _service.review(attemptId);
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SimReviewScreen(review: review)),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _snack('No se pudo abrir el intento', DS.error);
      }
    }
  }

  Widget _startBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: const BoxDecoration(
        color: DS.bg,
        border: Border(top: BorderSide(color: Color(0xFF252535))),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _starting ? null : _start,
          style: ElevatedButton.styleFrom(
            backgroundColor: _color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: _starting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text('Iniciar simulador',
                  style: DS.poppins(
                      size: 15,
                      weight: FontWeight.w700,
                      color: Colors.white)),
        ),
      ),
    );
  }

  // ── EXAM ──────────────────────────────────────────────────────────────────
  Widget _buildExam() {
    final draw = _draw!;
    final q = draw.questions[_current];
    final total = draw.questions.length;
    final answered = _answers.where((a) => a != null).length;
    final correctCount = _mode == 'entrenamiento'
        ? [
            for (var i = 0; i < total; i++)
              if (_answers[i] != null && _answers[i] == draw.questions[i].correct)
                1
          ].length
        : 0;

    return Column(
      children: [
        _examHud(answered, total, correctCount),
        // section banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: _color.withValues(alpha: 0.10),
          child: Text(
            '${q.sectionName.isEmpty ? 'Pregunta' : q.sectionName} · ${_current + 1}/$total',
            style: DS.poppins(
                size: 12, weight: FontWeight.w600, color: _color),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            children: [
              _questionCard(q),
              const SizedBox(height: 16),
              ...List.generate(q.options.length, (i) => _optionTile(q, i)),
            ],
          ),
        ),
        _examNav(total),
      ],
    );
  }

  Widget _examHud(int answered, int total, int correctCount) {
    final m = _remaining.inMinutes;
    final s = _remaining.inSeconds % 60;
    final urgent = _remaining.inMinutes < 10;
    final progress = total == 0 ? 0.0 : answered / total;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 10),
      decoration: const BoxDecoration(
        color: DS.bg,
        border: Border(bottom: BorderSide(color: Color(0xFF252535))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _confirmFinish,
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
              if (_mode == 'entrenamiento') ...[
                const Icon(Icons.bolt_rounded, color: DS.yellow, size: 18),
                const SizedBox(width: 3),
                Text('$correctCount',
                    style: DS.poppins(
                        size: 14,
                        weight: FontWeight.w800,
                        color: DS.yellow)),
                const SizedBox(width: 12),
              ],
              const Spacer(),
              // timer
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (urgent ? DS.red : _color).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 15, color: urgent ? DS.red : _color),
                    const SizedBox(width: 5),
                    Text(
                      '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
                      style: DS.poppins(
                          size: 14,
                          weight: FontWeight.w700,
                          color: urgent ? DS.red : _color),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _confirmFinish,
                style: TextButton.styleFrom(
                  backgroundColor: _color,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Finalizar',
                    style: DS.poppins(
                        size: 12,
                        weight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: DS.cardSoft,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionCard(SimQuestion q) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DS.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DS.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Pregunta ${_current + 1}',
                    style: DS.poppins(
                        size: 11, weight: FontWeight.w700, color: _color)),
              ),
              const SizedBox(width: 8),
              if (q.difficulty != null) _difficultyBadge(q.difficulty!),
              const Spacer(),
              InkWell(
                onTap: () => _reportar(q),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.flag_outlined,
                      size: 18, color: DS.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SimHtml(html: q.text, fontSize: 15),
        ],
      ),
    );
  }

  Widget _difficultyBadge(int d) {
    final map = {
      1: ('BAJO', DS.success),
      2: ('MEDIO', DS.warning),
      3: ('ALTO', DS.error),
    };
    final (label, color) = map[d] ?? ('', DS.textSecondary);
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style:
              DS.poppins(size: 9, weight: FontWeight.w700, color: color)),
    );
  }

  Widget _optionTile(SimQuestion q, int i) {
    final opt = q.options[i];
    final selected = _answers[_current] == opt.letra;
    final showFeedback =
        _mode == 'entrenamiento' && _locked.contains(_current);
    final isCorrect = opt.letra == q.correct;

    Color borderColor = DS.divider;
    Color bg = DS.card;
    Color letterBg = DS.cardSoft;
    Color letterColor = DS.textSecondary;
    IconData? trailing;
    Color? trailingColor;

    if (showFeedback) {
      if (isCorrect) {
        borderColor = DS.success;
        bg = DS.success.withValues(alpha: 0.08);
        letterBg = DS.success;
        letterColor = Colors.white;
        trailing = Icons.check_circle_rounded;
        trailingColor = DS.success;
      } else if (selected) {
        borderColor = DS.error;
        bg = DS.error.withValues(alpha: 0.08);
        letterBg = DS.error;
        letterColor = Colors.white;
        trailing = Icons.cancel_rounded;
        trailingColor = DS.error;
      }
    } else if (selected) {
      borderColor = _color;
      bg = _color.withValues(alpha: 0.12);
      letterBg = _color;
      letterColor = Colors.white;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _answer(opt.letra),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: selected ? 1.6 : 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: letterBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(opt.letra,
                      style: DS.poppins(
                          size: 13,
                          weight: FontWeight.w700,
                          color: letterColor)),
                ),
                const SizedBox(width: 12),
                Expanded(child: SimHtml(html: opt.html, fontSize: 14)),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Icon(trailing, color: trailingColor, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _examNav(int total) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
      decoration: const BoxDecoration(
        color: DS.bg,
        border: Border(top: BorderSide(color: Color(0xFF252535))),
      ),
      child: Row(
        children: [
          _navBtn(
            icon: Icons.chevron_left_rounded,
            label: 'Anterior',
            enabled: _current > 0,
            onTap: () => _goto(_current - 1),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _showPreguntasSheet,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: DS.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DS.divider),
              ),
              child: Text(
                '${(_current + 1).toString().padLeft(2, '0')} / $total',
                style: DS.poppins(
                    size: 13,
                    weight: FontWeight.w700,
                    color: DS.textPrimary),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _navBtn(
            icon: Icons.chevron_right_rounded,
            label: 'Siguiente',
            enabled: _current < total - 1,
            onTap: () => _goto(_current + 1),
            primary: true,
          ),
        ],
      ),
    );
  }

  Widget _navBtn({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: primary ? _color : DS.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary ? _color : DS.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!primary) Icon(icon, size: 18, color: DS.textPrimary),
                Text(label,
                    style: DS.poppins(
                        size: 13,
                        weight: FontWeight.w600,
                        color: primary ? Colors.white : DS.textPrimary)),
                if (primary) Icon(icon, size: 18, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPreguntasSheet() {
    final draw = _draw!;
    showModalBottomSheet(
      context: context,
      backgroundColor: DS.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Preguntas',
                  style: DS.poppins(
                      size: 16,
                      weight: FontWeight.w700,
                      color: DS.textPrimary)),
              const SizedBox(height: 12),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: draw.questions.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    childAspectRatio: 1,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (_, i) {
                    final answered = _answers[i] != null;
                    final isCurrent = i == _current;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _goto(i);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? _color
                              : answered
                                  ? _color.withValues(alpha: 0.22)
                                  : DS.cardSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCurrent
                                ? _color
                                : answered
                                    ? _color.withValues(alpha: 0.4)
                                    : DS.divider,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text('${i + 1}',
                            style: DS.poppins(
                                size: 12,
                                weight: FontWeight.w700,
                                color: isCurrent
                                    ? Colors.white
                                    : DS.textPrimary)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reportar(SimQuestion q) async {
    final ctrl = TextEditingController();
    bool enviando = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DS.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reportar pregunta',
                  style: DS.poppins(
                      size: 16,
                      weight: FontWeight.w700,
                      color: DS.textPrimary)),
              const SizedBox(height: 4),
              Text('¿Notaste un error en esta pregunta? Cuéntanos.',
                  style: DS.poppins(size: 12, color: DS.textSecondary)),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                maxLines: 4,
                style: DS.poppins(size: 13, color: DS.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ej: la respuesta correcta debería ser B...',
                  hintStyle: DS.poppins(size: 12, color: DS.textSecondary),
                  filled: true,
                  fillColor: DS.cardSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: enviando
                      ? null
                      : () async {
                          setSheet(() => enviando = true);
                          await _service.reportQuestion(
                            questionId: q.id,
                            observation: ctrl.text.trim(),
                            simulatorId: widget.item.id,
                            simulatorName: widget.item.nombre,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          _snack('Reporte enviado, ¡gracias!', DS.success);
                        },
                  child: enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text('Enviar reporte',
                          style: DS.poppins(
                              size: 14,
                              weight: FontWeight.w600,
                              color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────
  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: DS.purple),
      ),
    );
  }

  void _showSinIntentos() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: DS.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Sin intentos',
            style: DS.poppins(
                size: 17, weight: FontWeight.w700, color: DS.textPrimary)),
        content: Text(
          'Ya usaste tus intentos gratis. Adquiere más para seguir practicando.',
          style: DS.poppins(size: 13, color: DS.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Entendido',
                style: DS.poppins(size: 13, color: _color)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, Color color, {bool short = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: DS.poppins(size: 13, color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: short ? 900 : 2500),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }
}

// ── modelos ESPOCH locales ─────────────────────────────────────────────────
class _EspochCampo {
  final String label;
  final List<_EspochCarrera> carreras;
  _EspochCampo({required this.label, required this.carreras});
}

class _EspochCarrera {
  final String id;
  final String name;
  final String faculty;
  _EspochCarrera({required this.id, required this.name, required this.faculty});
}
