import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';

/// Renderiza el HTML de un enunciado u opción de simulador (con imágenes y
/// fórmulas LaTeX). Adaptado al tema oscuro de la app.
///
/// Las preguntas vienen igual que en el web: el texto puede mezclar HTML con
/// fórmulas KaTeX delimitadas por `\( ... \)` (inline), `\[ ... \]` o `$$ ... $$`
/// (bloque). Antes de renderizar, esas fórmulas se envuelven en un tag `<tex>`
/// (con el LaTeX codificado en base64 para que el parser HTML no lo corrompa) y
/// se pintan con `flutter_math_fork`. Réplica de `LatexText.jsx` del frontend web.
class SimHtml extends StatelessWidget {
  final String html;
  final double fontSize;
  final Color color;

  const SimHtml({
    super.key,
    required this.html,
    this.fontSize = 14,
    this.color = DS.textPrimary,
  });

  // ── Detección de fórmulas (mismos delimitadores que el web) ────────────────
  static final _block1 = RegExp(r'\$\$([\s\S]+?)\$\$'); // $$ ... $$
  static final _block2 = RegExp(r'\\\[([\s\S]+?)\\\]'); // \[ ... \]
  static final _inline = RegExp(r'\\\(([\s\S]+?)\\\)'); // \( ... \)

  static String _tag(String tex, bool block) {
    final data = base64.encode(utf8.encode(tex));
    return '<tex d="$data"${block ? ' b="1"' : ''}></tex>';
  }

  /// Sustituye las fórmulas por tags `<tex>` (bloque primero, luego inline).
  static String _prepara(String input) {
    var out = input;
    out = out.replaceAllMapped(_block1, (m) => _tag(m[1]!, true));
    out = out.replaceAllMapped(_block2, (m) => _tag(m[1]!, true));
    out = out.replaceAllMapped(_inline, (m) => _tag(m[1]!, false));
    return out;
  }

  /// KaTeX no entiende entidades HTML; las preguntas de Moodle a veces traen
  /// `&lt; &gt; &amp;` dentro de la fórmula. Se decodifican antes de renderizar.
  static String _decodeEntidades(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&');

  @override
  Widget build(BuildContext context) {
    final clean = html.trim();
    if (clean.isEmpty) return const SizedBox.shrink();

    return Html(
      data: _prepara(clean),
      extensions: [
        TagExtension.inline(
          tagsToExtend: const {'tex'},
          builder: (ctx) {
            final raw = ctx.attributes['d'] ?? '';
            final block = ctx.attributes['b'] == '1';
            String tex;
            try {
              tex = _decodeEntidades(utf8.decode(base64.decode(raw)));
            } catch (_) {
              tex = '';
            }
            if (tex.isEmpty) return const TextSpan(text: '');
            return WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Math.tex(
                tex,
                mathStyle: block ? MathStyle.display : MathStyle.text,
                textStyle: TextStyle(color: color, fontSize: fontSize + 1),
                onErrorFallback: (_) => Text(
                  tex,
                  style: TextStyle(color: color, fontSize: fontSize),
                ),
              ),
            );
          },
        ),
      ],
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          color: color,
          fontSize: FontSize(fontSize),
          fontFamily: 'Poppins',
          lineHeight: const LineHeight(1.4),
        ),
        'p': Style(margin: Margins.only(bottom: 6)),
        'img': Style(
          alignment: Alignment.center,
        ),
        'table': Style(
          backgroundColor: DS.cardSoft,
        ),
        'td': Style(
          padding: HtmlPaddings.all(4),
          border: const Border.fromBorderSide(
              BorderSide(color: DS.divider, width: 0.5)),
        ),
      },
    );
  }
}
