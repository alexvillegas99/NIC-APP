import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nic_pre_u/services/vocational_service.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';

class OVScreen extends StatefulWidget {
  const OVScreen({super.key});

  @override
  State<OVScreen> createState() => _OVScreenState();
}

class _OVScreenState extends State<OVScreen> {
  final _svc = VocationalService();

  bool _loading = true;
  bool _calculating = false;
  String? _error;
  Map<String, dynamic>? _estado;
  Map<String, dynamic>? _diagnostico;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final estado = await _svc.estado();
      Map<String, dynamic>? diagnostico;
      if (estado['diagnosticoListo'] == true) {
        try {
          diagnostico = await _svc.diagnostico();
        } catch (_) {
          diagnostico = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _estado = estado;
        _diagnostico = diagnostico;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _modulos {
    final raw = _estado?['modulos'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList()
      ..sort((a, b) {
        final aNum = (a['numero'] as num?)?.toInt() ?? 0;
        final bNum = (b['numero'] as num?)?.toInt() ?? 0;
        return aNum.compareTo(bNum);
      });
  }

  Future<void> _openModule(Map<String, dynamic> modulo) async {
    HapticFeedback.selectionClick();
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OVModuleScreen(
          slug: modulo['slug'].toString(),
          title: modulo['nombre']?.toString() ?? 'Test vocacional',
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _calcularDiagnostico() async {
    setState(() => _calculating = true);
    try {
      final result = await _svc.calcularDiagnostico();
      if (!mounted) return;
      setState(() {
        _diagnostico = result;
        _calculating = false;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _calculating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo calcular el reporte: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final completados = (_estado?['completados'] as num?)?.toInt() ?? 0;
    final total = (_estado?['totalModulos'] as num?)?.toInt() ?? 7;
    final percent = total == 0 ? 0.0 : completados / total;

    return Scaffold(
      backgroundColor: DS.bg,
      appBar: AppBar(
        backgroundColor: DS.bg,
        elevation: 0,
        leading: const BackButton(color: DS.textPrimary),
        title: Text('Orientación vocacional', style: DS.h3),
      ),
      body: RefreshIndicator(
        color: DS.purple,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: DS.purple))
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
                children: [
                  _HeroProgress(
                    completados: completados,
                    total: total,
                    percent: percent,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _ErrorBox(message: _error!, onRetry: _load),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'Camino vocacional',
                    style: DS.poppins(
                      size: 19,
                      weight: FontWeight.w900,
                      color: DS.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _modulos.isEmpty
                      ? _EmptyPathCard(onRetry: _load)
                      : _ModulePathCarousel(
                          modulos: _modulos,
                          onOpen: _openModule,
                        ),
                  const SizedBox(height: 10),
                  _FinalReportCard(
                    estado: _estado ?? const {},
                    diagnostico: _diagnostico,
                    calculating: _calculating,
                    onCalculate: _calcularDiagnostico,
                  ),
                ],
              ),
      ),
    );
  }
}

class OVModuleScreen extends StatefulWidget {
  final String slug;
  final String title;

  const OVModuleScreen({super.key, required this.slug, required this.title});

  @override
  State<OVModuleScreen> createState() => _OVModuleScreenState();
}

class _OVModuleScreenState extends State<OVModuleScreen> {
  final _svc = VocationalService();

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _detalle;
  List<dynamic> _answers = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detalle = await _svc.modulo(widget.slug);
      final total = (detalle['items'] is List)
          ? (detalle['items'] as List).length
          : 0;
      if (!mounted) return;
      setState(() {
        _detalle = detalle;
        _answers = List<dynamic>.filled(total, null, growable: false);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _items {
    final raw = _detalle?['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  String get _format => _detalle?['formato']?.toString() ?? '';

  bool get _complete =>
      _answers.isNotEmpty && _answers.every((answer) => answer != null);

  void _setAnswer(int index, dynamic value) {
    HapticFeedback.selectionClick();
    setState(() => _answers[index] = value);
  }

  Future<void> _submit() async {
    if (!_complete || _submitting) return;
    setState(() => _submitting = true);
    try {
      final result = await _svc.submitModulo(
        slug: widget.slug,
        answers: _answers,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      await showDialog<void>(
        context: context,
        builder: (_) => _ResultDialog(result: result),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar el test: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final modulo = Map<String, dynamic>.from(_detalle?['modulo'] ?? {});
    final color = _hexColor(modulo['color']?.toString(), DS.purple);
    final answered = _answers.where((a) => a != null).length;
    final progress = _answers.isEmpty ? 0.0 : answered / _answers.length;

    return Scaffold(
      backgroundColor: DS.bg,
      appBar: AppBar(
        backgroundColor: DS.bg,
        elevation: 0,
        leading: const BackButton(color: DS.textPrimary),
        title: Text(widget.title, style: DS.h3),
      ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF141422),
                  border: Border(top: BorderSide(color: DS.divider)),
                ),
                child: ElevatedButton.icon(
                  onPressed: _complete ? _submit : null,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    _submitting ? 'Guardando...' : 'Terminar test',
                    style: DS.poppins(
                      size: 15,
                      weight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    disabledBackgroundColor: DS.cardSoft,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: DS.purple))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: _ErrorBox(message: _error!, onRetry: _load),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
              children: [
                _ModuleHeader(
                  modulo: modulo,
                  color: color,
                  answered: answered,
                  total: _answers.length,
                  progress: progress,
                ),
                const SizedBox(height: 16),
                for (final entry in _items.asMap().entries) ...[
                  _QuestionCard(
                    index: entry.key,
                    item: entry.value,
                    format: _format,
                    value: _answers[entry.key],
                    color: color,
                    onChanged: (value) => _setAnswer(entry.key, value),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _HeroProgress extends StatelessWidget {
  final int completados;
  final int total;
  final double percent;

  const _HeroProgress({
    required this.completados,
    required this.total,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DS.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DS.purple.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: DS.purple.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: DS.purple.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.psychology_alt_rounded,
                  color: DS.purple,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Programa vocacional',
                      style: DS.poppins(
                        size: 21,
                        weight: FontWeight.w900,
                        color: DS.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$completados de $total tests completados',
                      style: DS.poppins(
                        size: 12,
                        weight: FontWeight.w600,
                        color: DS.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: percent.clamp(0.0, 1.0),
              backgroundColor: DS.cardSoft,
              valueColor: const AlwaysStoppedAnimation<Color>(DS.purple),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModulePathCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> modulos;
  final ValueChanged<Map<String, dynamic>> onOpen;

  const _ModulePathCarousel({required this.modulos, required this.onOpen});

  @override
  State<_ModulePathCarousel> createState() => _ModulePathCarouselState();
}

class _ModulePathCarouselState extends State<_ModulePathCarousel> {
  late final PageController _ctrl;
  int _active = 0;

  @override
  void initState() {
    super.initState();
    final firstAvailable = widget.modulos.indexWhere((m) {
      final estado = m['estado']?.toString() ?? 'locked';
      return estado == 'available';
    });
    _active = firstAvailable < 0 ? 0 : firstAvailable;
    _ctrl = PageController(initialPage: _active, viewportFraction: 0.84);
  }

  @override
  void didUpdateWidget(covariant _ModulePathCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_active >= widget.modulos.length) _active = 0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _active.clamp(0, widget.modulos.length - 1).toInt();
    final activeModulo = widget.modulos[activeIndex];
    final activeColor = _hexColor(activeModulo['color']?.toString(), DS.purple);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final carouselHeight =
        (screenWidth < 380 ? 326.0 : 318.0) + (textScale > 1 ? 18.0 : 0.0);

    return Column(
      children: [
        SizedBox(
          height: carouselHeight,
          child: PageView.builder(
            controller: _ctrl,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.modulos.length,
            onPageChanged: (value) => setState(() => _active = value),
            itemBuilder: (context, index) {
              final selected = index == _active;
              final modulo = widget.modulos[index];
              return AnimatedScale(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                scale: selected ? 1 : 0.91,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: selected ? 1 : 0.48,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _ModuleSlideCard(
                      modulo: modulo,
                      active: selected,
                      onTap: () => widget.onOpen(modulo),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _ModuleDots(
          count: widget.modulos.length,
          activeIndex: _active,
          color: activeColor,
        ),
        const SizedBox(height: 10),
        Text(
          'Desliza para ver los 7 tests en orden',
          textAlign: TextAlign.center,
          style: DS.poppins(
            size: 11,
            weight: FontWeight.w700,
            color: DS.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ModuleSlideCard extends StatelessWidget {
  final Map<String, dynamic> modulo;
  final bool active;
  final VoidCallback onTap;

  const _ModuleSlideCard({
    required this.modulo,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final numero = (modulo['numero'] as num?)?.toInt() ?? 0;
    final estado = modulo['estado']?.toString() ?? 'locked';
    final completed = estado == 'completed';
    final available = estado == 'available' || completed;
    final color = _hexColor(modulo['color']?.toString(), DS.purple);
    final stateLabel = completed
        ? 'Completado'
        : available
        ? 'Disponible'
        : 'Bloqueado';
    final stateIcon = completed
        ? Icons.check_rounded
        : available
        ? Icons.play_arrow_rounded
        : Icons.lock_rounded;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: available ? onTap : null,
        borderRadius: BorderRadius.circular(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 322;
            final cardPadding = compact ? 16.0 : 18.0;

            return Container(
              padding: EdgeInsets.all(cardPadding),
              decoration: BoxDecoration(
                color: DS.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: available
                      ? color.withValues(alpha: active ? 0.52 : 0.32)
                      : DS.divider.withValues(alpha: 0.8),
                  width: active ? 1.4 : 1,
                ),
                boxShadow: [
                  if (active && available)
                    BoxShadow(
                      color: color.withValues(alpha: 0.16),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withValues(
                            alpha: available ? 0.16 : 0.08,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '$numero',
                          style: DS.poppins(
                            size: 18,
                            weight: FontWeight.w900,
                            color: available ? color : DS.textSecondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: (available ? color : DS.textSecondary)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              stateIcon,
                              size: 14,
                              color: available ? color : DS.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              stateLabel,
                              style: DS.poppins(
                                size: 10,
                                weight: FontWeight.w900,
                                color: available ? color : DS.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 12 : 16),
                  Text(
                    (modulo['nombre'] ?? 'Test vocacional').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DS.poppins(
                      size: compact ? 18 : 20,
                      weight: FontWeight.w900,
                      color: available
                          ? DS.textPrimary
                          : DS.textPrimary.withValues(alpha: 0.46),
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (modulo['descripcion'] ?? '').toString(),
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: DS.poppins(
                      size: 12,
                      weight: FontWeight.w500,
                      height: 1.35,
                      color: DS.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      _TinyInfoPill(
                        icon: Icons.timer_outlined,
                        label: '${modulo['tiempoMin'] ?? 10} min',
                        color: color,
                        enabled: available,
                      ),
                      const SizedBox(width: 8),
                      _TinyInfoPill(
                        icon: Icons.insights_rounded,
                        label: completed ? 'Mini resultado' : 'Paso $numero/7',
                        color: color,
                        enabled: available,
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 10 : 14),
                  SizedBox(
                    height: compact ? 42 : 46,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: available ? color : DS.cardSoft,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        completed
                            ? 'Revisar módulo'
                            : available
                            ? 'Empezar módulo'
                            : 'Completa el anterior',
                        style: DS.poppins(
                          size: 13,
                          weight: FontWeight.w900,
                          color: available ? Colors.white : DS.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TinyInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;

  const _TinyInfoPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final effective = enabled ? color : DS.textSecondary;
    return Expanded(
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: effective.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: effective.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: effective),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DS.poppins(
                  size: 10,
                  weight: FontWeight.w800,
                  color: effective,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleDots extends StatelessWidget {
  final int count;
  final int activeIndex;
  final Color color;

  const _ModuleDots({
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
            color: active ? color : Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

class _EmptyPathCard extends StatelessWidget {
  final VoidCallback onRetry;

  const _EmptyPathCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DS.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DS.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: DS.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.route_rounded, color: DS.purple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No se pudieron cargar los módulos vocacionales.',
              style: DS.poppins(size: 12, color: DS.textSecondary),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _FinalReportCard extends StatelessWidget {
  final Map<String, dynamic> estado;
  final Map<String, dynamic>? diagnostico;
  final bool calculating;
  final VoidCallback onCalculate;

  const _FinalReportCard({
    required this.estado,
    required this.diagnostico,
    required this.calculating,
    required this.onCalculate,
  });

  @override
  Widget build(BuildContext context) {
    final completed = estado['todosCompletados'] == true;
    final ready = estado['diagnosticoListo'] == true || diagnostico != null;
    final diag = Map<String, dynamic>.from(diagnostico?['diagnostico'] ?? {});
    final careers = (diag['carreras'] is List) ? diag['carreras'] as List : [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DS.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: completed
              ? DS.green.withValues(alpha: 0.45)
              : DS.divider.withValues(alpha: 0.9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (completed ? DS.green : DS.textSecondary).withValues(
                    alpha: 0.14,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  ready
                      ? Icons.assignment_turned_in_rounded
                      : completed
                      ? Icons.auto_awesome_rounded
                      : Icons.lock_rounded,
                  color: completed ? DS.green : DS.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reporte final',
                      style: DS.poppins(
                        size: 17,
                        weight: FontWeight.w900,
                        color: DS.textPrimary,
                      ),
                    ),
                    Text(
                      completed
                          ? 'Diagnóstico con tus 7 tests'
                          : 'Se desbloquea al completar los 7 tests',
                      style: DS.poppins(size: 11, color: DS.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!ready && completed) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: calculating ? null : onCalculate,
              icon: calculating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(calculating ? 'Calculando...' : 'Calcular reporte'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DS.green,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
          if (ready && careers.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Carrera principal recomendada',
              style: DS.poppins(
                size: 13,
                weight: FontWeight.w800,
                color: DS.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _PrimaryCareerResult(
              career: Map<String, dynamic>.from(careers.first as Map),
            ),
            if (careers.length > 1) ...[
              const SizedBox(height: 12),
              Text(
                'Alternativas',
                style: DS.poppins(
                  size: 13,
                  weight: FontWeight.w800,
                  color: DS.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              for (final raw in careers.skip(1).take(2))
                _CareerResult(career: Map<String, dynamic>.from(raw as Map)),
            ],
          ],
          if (ready && careers.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              diag['madurez'] is Map
                  ? (diag['madurez']['mensaje'] ?? 'Reporte calculado.')
                        .toString()
                  : 'Reporte calculado.',
              style: DS.poppins(
                size: 12,
                height: 1.35,
                color: DS.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModuleHeader extends StatelessWidget {
  final Map<String, dynamic> modulo;
  final Color color;
  final int answered;
  final int total;
  final double progress;

  const _ModuleHeader({
    required this.modulo,
    required this.color,
    required this.answered,
    required this.total,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DS.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                (modulo['emoji'] ?? '🧭').toString(),
                style: const TextStyle(fontSize: 34),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      modulo['nombre']?.toString() ?? 'Test vocacional',
                      style: DS.poppins(
                        size: 19,
                        weight: FontWeight.w900,
                        color: DS.textPrimary,
                      ),
                    ),
                    Text(
                      '${modulo['tiempoMin'] ?? 10} min · $answered/$total respuestas',
                      style: DS.poppins(size: 11, color: DS.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            modulo['descripcion']?.toString() ?? '',
            style: DS.poppins(size: 12, height: 1.35, color: DS.textSecondary),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress.clamp(0.0, 1.0),
              backgroundColor: DS.cardSoft,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> item;
  final String format;
  final dynamic value;
  final Color color;
  final ValueChanged<dynamic> onChanged;

  const _QuestionCard({
    required this.index,
    required this.item,
    required this.format,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = (item['text'] ?? item['prompt'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DS.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: value == null ? DS.divider : color.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${index + 1}',
                  style: DS.poppins(
                    size: 11,
                    weight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (item['part'] != null)
                Text(
                  'Parte ${item['part']}',
                  style: DS.poppins(
                    size: 10,
                    weight: FontWeight.w800,
                    color: color,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: DS.poppins(
              size: 14,
              weight: FontWeight.w700,
              height: 1.35,
              color: DS.textPrimary,
            ),
          ),
          if (item['a'] != null && item['b'] != null) ...[
            const SizedBox(height: 10),
            _OptionButton(
              label: item['a'].toString(),
              selected: value == 'a',
              color: color,
              onTap: () => onChanged('a'),
            ),
            const SizedBox(height: 8),
            _OptionButton(
              label: item['b'].toString(),
              selected: value == 'b',
              color: color,
              onTap: () => onChanged('b'),
            ),
          ] else ...[
            const SizedBox(height: 12),
            _buildControl(),
          ],
        ],
      ),
    );
  }

  Widget _buildControl() {
    final input = item['input']?.toString();
    if (format == 'binary' || input == 'binary') {
      return Row(
        children: [
          Expanded(
            child: _OptionButton(
              label: 'Sí',
              selected: value == true,
              color: color,
              onTap: () => onChanged(true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _OptionButton(
              label: 'No',
              selected: value == false,
              color: color,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      );
    }

    if (format == 'likert5') {
      return _ScaleSelector(
        values: const [1, 2, 3, 4, 5],
        labels: const ['Nada', 'Poco', 'Medio', 'Bastante', 'Mucho'],
        value: value,
        color: color,
        onChanged: onChanged,
      );
    }

    if (format == 'likert6') {
      return _ScaleSelector(
        values: const [1, 2, 3, 4, 5, 6],
        labels: const ['1', '2', '3', '4', '5', '6'],
        value: value,
        color: color,
        onChanged: onChanged,
      );
    }

    if (format == 'likert4') {
      return _ScaleSelector(
        values: const [1, 2, 3, 4],
        labels: const ['Nada', 'Poco', 'Bastante', 'Mucho'],
        value: value,
        color: color,
        onChanged: onChanged,
      );
    }

    final options = _optionsForItem();
    return Column(
      children: [
        for (final opt in options) ...[
          _OptionButton(
            label: opt.label,
            selected: value == opt.value,
            color: color,
            onTap: () => onChanged(opt.value),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  List<_VocOption> _optionsForItem() {
    final raw = item['options'];
    if (raw is List && raw.isNotEmpty) {
      return raw.whereType<Map>().map((opt) {
        final map = Map<String, dynamic>.from(opt);
        final value = (map['value'] ?? map['label'] ?? '').toString();
        final label = [
          if (map['label'] != null) map['label'].toString(),
          if (map['text'] != null) map['text'].toString(),
        ].join(' · ');
        return _VocOption(value: value, label: label.isEmpty ? value : label);
      }).toList();
    }

    final input = item['input']?.toString();
    if (input == 'scale3') {
      return const [
        _VocOption(value: 'mas', label: 'Más que los demás'),
        _VocOption(value: 'igual', label: 'Igual que los demás'),
        _VocOption(value: 'menos', label: 'Menos que los demás'),
      ];
    }
    if (input == 'choice6') {
      return const [
        _VocOption(value: 'a', label: 'A'),
        _VocOption(value: 'b', label: 'B'),
        _VocOption(value: 'c', label: 'C'),
        _VocOption(value: 'd', label: 'D'),
        _VocOption(value: 'e', label: 'E'),
        _VocOption(value: 'f', label: 'F'),
      ];
    }

    return const [];
  }
}

class _ScaleSelector extends StatelessWidget {
  final List<int> values;
  final List<String> labels;
  final dynamic value;
  final Color color;
  final ValueChanged<int> onChanged;

  const _ScaleSelector({
    required this.values,
    required this.labels,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(values[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == values[i] ? color : DS.cardSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: value == values[i]
                        ? color
                        : DS.divider.withValues(alpha: 0.9),
                  ),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DS.poppins(
                    size: 10,
                    weight: FontWeight.w800,
                    color: value == values[i] ? Colors.white : DS.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          if (i < values.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _OptionButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color : DS.cardSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : DS.divider.withValues(alpha: 0.9),
          ),
        ),
        child: Text(
          label,
          style: DS.poppins(
            size: 12,
            weight: FontWeight.w800,
            height: 1.25,
            color: selected ? Colors.white : DS.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _ResultDialog extends StatelessWidget {
  final Map<String, dynamic> result;

  const _ResultDialog({required this.result});

  @override
  Widget build(BuildContext context) {
    final modulo = Map<String, dynamic>.from(result['modulo'] ?? {});
    final tareas = (result['tareasHumanas'] is List)
        ? result['tareasHumanas'] as List
        : const [];

    return AlertDialog(
      backgroundColor: DS.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Test guardado',
        style: DS.poppins(
          size: 19,
          weight: FontWeight.w900,
          color: DS.textPrimary,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              modulo['nombre']?.toString() ?? 'Tu test fue registrado.',
              style: DS.poppins(
                size: 13,
                height: 1.35,
                color: DS.textSecondary,
              ),
            ),
            if (tareas.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Sugerencias para reflexionar',
                style: DS.poppins(
                  size: 13,
                  weight: FontWeight.w800,
                  color: DS.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              for (final raw in tareas.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '• ${(raw is Map ? raw['texto'] : raw).toString()}',
                    style: DS.poppins(
                      size: 12,
                      height: 1.3,
                      color: DS.textSecondary,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Continuar',
            style: DS.poppins(
              size: 13,
              weight: FontWeight.w800,
              color: DS.purple,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryCareerResult extends StatelessWidget {
  final Map<String, dynamic> career;

  const _PrimaryCareerResult({required this.career});

  String _universities() {
    final raw =
        career['universidades'] ??
        career['universities'] ??
        career['dondeEstudiar'];
    if (raw is List && raw.isNotEmpty) {
      return raw.take(3).map((e) => e.toString()).join(' · ');
    }
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final universities = _universities();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DS.green.withValues(alpha: 0.22),
            DS.purple.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DS.green.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: DS.green.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: DS.green,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      career['nombre']?.toString() ?? 'Carrera recomendada',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DS.poppins(
                        size: 16,
                        weight: FontWeight.w900,
                        color: DS.textPrimary,
                        height: 1.12,
                      ),
                    ),
                    Text(
                      '${career['match'] ?? 0}% de match',
                      style: DS.poppins(
                        size: 11,
                        weight: FontWeight.w800,
                        color: DS.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (universities.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.account_balance_rounded,
                  size: 16,
                  color: DS.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    universities,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DS.poppins(
                      size: 12,
                      height: 1.3,
                      color: DS.textSecondary,
                    ),
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

class _CareerResult extends StatelessWidget {
  final Map<String, dynamic> career;

  const _CareerResult({required this.career});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DS.cardSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DS.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${career['rank'] ?? '-'}',
              style: DS.poppins(
                size: 13,
                weight: FontWeight.w900,
                color: DS.green,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  career['nombre']?.toString() ?? 'Carrera recomendada',
                  style: DS.poppins(
                    size: 13,
                    weight: FontWeight.w800,
                    color: DS.textPrimary,
                  ),
                ),
                Text(
                  '${career['match'] ?? 0}% · ${career['area'] ?? ''}',
                  style: DS.poppins(size: 11, color: DS.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DS.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DS.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No se pudo cargar',
            style: DS.poppins(
              size: 15,
              weight: FontWeight.w900,
              color: DS.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: DS.poppins(size: 12, height: 1.35, color: DS.textSecondary),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _VocOption {
  final String value;
  final String label;

  const _VocOption({required this.value, required this.label});
}

Color _hexColor(String? value, Color fallback) {
  if (value == null || value.isEmpty) return fallback;
  final hex = value.replaceAll('#', '').trim();
  if (hex.length != 6) return fallback;
  return Color(int.parse('FF$hex', radix: 16));
}
