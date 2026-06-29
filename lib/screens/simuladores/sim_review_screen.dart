import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nic_pre_u/services/simulador_service.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';
import 'package:nic_pre_u/screens/simuladores/sim_html.dart';

/// Revisión de un intento de simulador (resultado + pregunta por pregunta).
class SimReviewScreen extends StatelessWidget {
  final SimReview review;
  final bool justFinished;

  const SimReviewScreen({
    super.key,
    required this.review,
    this.justFinished = false,
  });

  Color get _color => simColor(review.sim.color);

  String? _answerFor(int i) =>
      i < review.answers.length ? review.answers[i] : null;

  @override
  Widget build(BuildContext context) {
    final r = review.result;
    final pct = r.scorePct.round();

    // aciertos por sección
    final Map<String, List<int>> bySection = {}; // nombre → [aciertos, total]
    for (var i = 0; i < review.questions.length; i++) {
      final q = review.questions[i];
      final name = q.sectionName.isEmpty ? 'General' : q.sectionName;
      final entry = bySection.putIfAbsent(name, () => [0, 0]);
      entry[1]++;
      if (_answerFor(i) == q.correct) entry[0]++;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: DS.bg,
        body: SafeArea(
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                  itemCount: review.questions.length + 1,
                  itemBuilder: (context, idx) {
                    if (idx == 0) {
                      return _summary(pct, r, bySection);
                    }
                    final i = idx - 1;
                    return _questionReview(i, review.questions[i]);
                  },
                ),
              ),
              if (justFinished) _bottomBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 12),
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
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white, size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(justFinished ? '¡Resultado!' : 'Revisión',
                    style: DS.poppins(
                        size: 18,
                        weight: FontWeight.w800,
                        color: DS.textPrimary)),
                Text('Simulador ${review.sim.uni}',
                    style: DS.poppins(size: 11, color: DS.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(int pct, SimResult r, Map<String, List<int>> bySection) {
    final color = pct >= 70
        ? DS.success
        : pct >= 50
            ? DS.warning
            : DS.error;
    final mins = (r.durationSeconds / 60).floor();
    final secs = r.durationSeconds % 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DS.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: CircularProgressIndicator(
                        value: pct / 100,
                        strokeWidth: 7,
                        backgroundColor: DS.cardSoft,
                        color: color,
                      ),
                    ),
                    Text('$pct%',
                        style: DS.poppins(
                            size: 19,
                            weight: FontWeight.w800,
                            color: color)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${r.correctCount} / ${r.totalQuestions} aciertos',
                        style: DS.poppins(
                            size: 16,
                            weight: FontWeight.w800,
                            color: DS.textPrimary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 14, color: DS.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${mins}m ${secs}s',
                          style: DS.poppins(
                              size: 12, color: DS.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.star_rounded, size: 14, color: DS.yellow),
                        const SizedBox(width: 4),
                        Text('${r.score.round()} pts',
                            style: DS.poppins(
                                size: 12, color: DS.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (bySection.length > 1) ...[
            const SizedBox(height: 16),
            const Divider(color: DS.divider, height: 1),
            const SizedBox(height: 14),
            ...bySection.entries.map((e) {
              final aciertos = e.value[0];
              final total = e.value[1];
              final p = total == 0 ? 0.0 : aciertos / total;
              final c = p >= 0.7
                  ? DS.success
                  : p >= 0.5
                      ? DS.warning
                      : DS.error;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(e.key,
                              style: DS.poppins(
                                  size: 12, color: DS.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text('$aciertos/$total',
                            style: DS.poppins(
                                size: 11,
                                weight: FontWeight.w600,
                                color: c)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: p,
                        minHeight: 5,
                        backgroundColor: DS.cardSoft,
                        color: c,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _questionReview(int i, SimQuestion q) {
    final given = _answerFor(i);
    final acerto = given == q.correct;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DS.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: given == null
              ? DS.divider
              : (acerto ? DS.success : DS.error).withValues(alpha: 0.45),
        ),
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
                child: Text('Pregunta ${i + 1}',
                    style: DS.poppins(
                        size: 11, weight: FontWeight.w700, color: _color)),
              ),
              const Spacer(),
              Icon(
                given == null
                    ? Icons.remove_circle_outline_rounded
                    : (acerto
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded),
                size: 18,
                color: given == null
                    ? DS.textSecondary
                    : (acerto ? DS.success : DS.error),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SimHtml(html: q.text, fontSize: 14),
          const SizedBox(height: 12),
          ...q.options.map((opt) {
            final isCorrect = opt.letra == q.correct;
            final isGiven = opt.letra == given;
            Color border = DS.divider;
            Color bg = DS.cardSoft;
            Color letterBg = DS.cardSoft;
            Color letterColor = DS.textSecondary;
            if (isCorrect) {
              border = DS.success;
              bg = DS.success.withValues(alpha: 0.08);
              letterBg = DS.success;
              letterColor = Colors.white;
            } else if (isGiven) {
              border = DS.error;
              bg = DS.error.withValues(alpha: 0.08);
              letterBg = DS.error;
              letterColor = Colors.white;
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: letterBg,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: Text(opt.letra,
                          style: DS.poppins(
                              size: 12,
                              weight: FontWeight.w700,
                              color: letterColor)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: SimHtml(html: opt.html, fontSize: 13)),
                  ],
                ),
              ),
            );
          }),
          if (given == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('No respondiste · la correcta era ${q.correct}',
                  style: DS.poppins(size: 11, color: DS.textSecondary)),
            ),
        ],
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
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
          onPressed: () => Navigator.maybePop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: _color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: Text('Volver al simulador',
              style: DS.poppins(
                  size: 14, weight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    );
  }
}
