import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // para formatear fecha del header

import 'package:nic_pre_u/services/auth_service.dart';
import 'package:nic_pre_u/services/asistentes_service.dart';
import 'package:nic_pre_u/services/course_service.dart';
// ✅ Importa DS SIN alias para usar DS.bg, DS.card, etc.
import 'package:nic_pre_u/shared/ui/design_system.dart';

class NotasReportScreen extends StatefulWidget {
  const NotasReportScreen({super.key});

  @override
  State<NotasReportScreen> createState() => _NotasReportScreenState();
}

class _NotasReportScreenState extends State<NotasReportScreen> {
  final _auth = AuthService();
  final _svc = AsistentesService();

  String _cedula = '';
  String _nombre = '-';
  String _cursoNombre = '-';

  bool _cargando = false;
  String? _error;
  List<dynamic> _cursos = [];
  final _reports = CourseService();
  // ===== Filtros =====
  final _buscarCtrl = TextEditingController();
  DateTime? _desde;
  DateTime? _hasta;

  @override
  void initState() {
    super.initState(); 
    _load();
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final user = await _auth.getUser();
      _cedula = (user?['cedula'] ?? '').toString().trim();
      _nombre = (user?['nombre'] ?? user?['name'] ?? '-').toString();
      _cursoNombre = (user?['cursoNombre'] ?? '-').toString();

      if (_cedula.isEmpty) {
        setState(() {
          _error = 'No se encontró cédula en la sesión.';
          _cargando = false;
        });
        return;
      }

      final res = await _svc.obtenerNotasV2(_cedula);
      setState(() {
        _cursos = (res is List) ? res : [];
        _cargando = false;
      });
    } catch (_) {
      setState(() {
        _error = 'No se pudo obtener la información.';
        _cargando = false;
      });
    }
  }

  // ====== Helpers ======
  int get totalItems {
    int t = 0;
    for (final c in _cursos) {
      final grades = (c['grades'] ?? {}) as Map<String, dynamic>;
      for (final v in grades.values) {
        if (v is List) t += v.length;
      }
    }
    return t;
  }

  String _fmt(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d);

  // Parseador de fecha ES (similar a tu Angular)
  DateTime? _parseFechaEs(dynamic v) {
    if (v == null) return null;
    if (v is num) {
      final n = v.toInt();
      return DateTime.fromMillisecondsSinceEpoch(n < 1e12 ? n * 1000 : n);
    }
    if (v is DateTime) return v;

    String s = v.toString().trim();
    if (s.isEmpty || s == '-' || s == '—') return null;

    final meses = <String, int>{
      'ene': 1,
      'enero': 1,
      'feb': 2,
      'febrero': 2,
      'mar': 3,
      'marzo': 3,
      'abr': 4,
      'abril': 4,
      'may': 5,
      'mayo': 5,
      'jun': 6,
      'junio': 6,
      'jul': 7,
      'julio': 7,
      'ago': 8,
      'agosto': 8,
      'sep': 9,
      'sept': 9,
      'set': 9,
      'septiembre': 9,
      'setiembre': 9,
      'oct': 10,
      'octubre': 10,
      'nov': 11,
      'noviembre': 11,
      'dic': 12,
      'diciembre': 12,
    };

    String stripDiacritics(String s) {
      return s
          .replaceAll(RegExp(r'[ÁÀÂÄ]'), 'A')
          .replaceAll(RegExp(r'[áàâä]'), 'a')
          .replaceAll(RegExp(r'[ÉÈÊË]'), 'E')
          .replaceAll(RegExp(r'[éèêë]'), 'e')
          .replaceAll(RegExp(r'[ÍÌÎÏ]'), 'I')
          .replaceAll(RegExp(r'[íìîï]'), 'i')
          .replaceAll(RegExp(r'[ÓÒÔÖ]'), 'O')
          .replaceAll(RegExp(r'[óòôö]'), 'o')
          .replaceAll(RegExp(r'[ÚÙÛÜ]'), 'U')
          .replaceAll(RegExp(r'[úùûü]'), 'u')
          .replaceAll(RegExp(r'[Ñ]'), 'N')
          .replaceAll(RegExp(r'[ñ]'), 'n');
    }

    s = stripDiacritics(s).toLowerCase();

    // "19 de septiembre de 2025, 16:30"  ó "19 de septiembre de 2025 16:30"
    final m1 = RegExp(
      r'^(\d{1,2})\s+de\s+([a-z\.]+)\s+de\s+(\d{4})(?:[\s,]+(\d{1,2}):(\d{2}))?$',
    ).firstMatch(s);

    if (m1 != null) {
      final d = int.parse(m1.group(1)!);
      final mesTxt = (m1.group(2) ?? '').replaceAll('.', '');
      final y = int.parse(m1.group(3)!);
      final hh = m1.group(4) != null ? int.parse(m1.group(4)!) : 0;
      final mm = m1.group(5) != null ? int.parse(m1.group(5)!) : 0;
      final mi = meses[mesTxt] ?? meses[mesTxt.substring(0, 3)];
      if (mi != null) return DateTime(y, mi, d, hh, mm);
    }

    // "17/09/2025 14:35"  ó  "17-09-2025 14:35"
    final m2 = RegExp(
      r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})(?:\s+(\d{1,2}):(\d{2}))?$',
    ).firstMatch(s);

    if (m2 != null) {
      final d = int.parse(m2.group(1)!);
      final mi = int.parse(m2.group(2)!);
      final y = int.parse(m2.group(3)!);
      final hh = m2.group(4) != null ? int.parse(m2.group(4)!) : 0;
      final mm = m2.group(5) != null ? int.parse(m2.group(5)!) : 0;
      return DateTime(y, mi, d, hh, mm);
    }

    // Último recurso (ISO)
    try {
      final tmp = DateTime.parse(v.toString());
      return tmp;
    } catch (_) {
      return null;
    }
  }

  // Filtra items por nombre y rango de fechas
  List _filtrarItems(List items) {
    final q = _buscarCtrl.text.trim().toLowerCase();
    final d1 = _desde != null
        ? DateTime(_desde!.year, _desde!.month, _desde!.day, 0, 0, 0)
        : null;
    final d2 = _hasta != null
        ? DateTime(_hasta!.year, _hasta!.month, _hasta!.day, 23, 59, 59)
        : null;

    return items.where((e) {
      // nombre actividad
      if (q.isNotEmpty) {
        final n = ((e['itemName'] ?? e['name'] ?? '') as String).toLowerCase();
        if (!n.contains(q)) return false;
      }
      // fechas
      final dt = _parseFechaEs(e['gradedategraded']);
      if (d1 != null && (dt == null || dt.isBefore(d1))) return false;
      if (d2 != null && (dt == null || dt.isAfter(d2))) return false;

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: DS.bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: DS.bg,
          elevation: 0,
          iconTheme: IconThemeData(color: DS.text),
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: DS.text,
          ),
        ),
        colorScheme: const ColorScheme.dark(
          primary: DS.primary, // morado principal
          secondary: DS.accent, // acento
          surface: DS.card, // cards
          onSurface: DS.text, // textos
        ),
        textTheme: Theme.of(
          context,
        ).textTheme.apply(bodyColor: DS.text, displayColor: DS.text),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: DS.cardSoft, // inputs
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: DS.cardSoft.withOpacity(.8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: DS.primary, width: 1.2),
          ),
          hintStyle: const TextStyle(color: DS.textDim),
          labelStyle: const TextStyle(color: DS.textDim),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: Text('Reporte Moodle', style: DS.h2),
        ),
        body: RefreshIndicator(
          color: DS.primary,
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // ===== Header con datos del usuario y acciones =====
              _HeaderBonitoCompact(
                nombre: _nombre,
                cedula: _cedula.isEmpty ? '-' : _cedula,
                curso: _cursoNombre,
                cursosCount: _cursos.length,
                itemsCount: totalItems,
                cargando: _cargando,
                onActualizar: _load,
                onDescargar: _cursos.isEmpty
                    ? null
                    : () async {
                        try {
                          // Si tienes un loader propio, úsalo aquí. Ejemplo sin loader:
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Descargando PDF...')),
                          );

                          await _reports.descargarNotasPdfDelUsuario();

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('PDF descargado y abierto.'),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('No se pudo abrir el PDF: $e'),
                            ),
                          );
                        }
                      },
              ),

              // ===== Barra de filtros =====
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  decoration: DS.cardDeco(),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        runSpacing: 10,
                        spacing: 12,
                        children: [
                          // Buscar actividad
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: 220,
                              maxWidth: 420,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Buscar actividad', style: DS.pDim),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _buscarCtrl,
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    hintText: 'Nombre de actividad',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Desde
                          _FechaPicker(
                            label: 'Desde',
                            value: _desde,
                            onPick: (d) => setState(() => _desde = d),
                          ),
                          // Hasta
                          _FechaPicker(
                            label: 'Hasta',
                            value: _hasta,
                            onPick: (d) => setState(() => _hasta = d),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (_cargando) const LinearProgressIndicator(minHeight: 3),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),

              // ===== Cursos =====
              const SizedBox(height: 4),
              ..._cursos.map((c) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _CursoCardDark(
                    curso: c,
                    headerBg: DS.card,
                    onFiltrarItems: _filtrarItems,
                  ),
                );
              }),

              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _LeyendaCalificaciones(),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Center(
                  child: Text(
                    'Reporte generado por el NIC.Be',
                    style: DS.pDim.copyWith(fontSize: 12),
                  ),
                ),
              ),

              // ===== Leyenda de calificaciones =====
            ],
          ),
        ),
      ),
    );
  }
}

/// ======= Header bonito (compacto) =======
class _HeaderBonitoCompact extends StatelessWidget {
  final String nombre, cedula, curso;
  final int cursosCount, itemsCount;
  final bool cargando;
  final VoidCallback onActualizar;
  final VoidCallback? onDescargar;

  const _HeaderBonitoCompact({
    required this.nombre,
    required this.cedula,
    required this.curso,
    required this.cursosCount,
    required this.itemsCount,
    required this.cargando,
    required this.onActualizar,
    required this.onDescargar,
  });

  @override
  Widget build(BuildContext context) {
    final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [DS.primary, DS.primary2], // tu gradiente
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // fila fecha
          Row(
            children: [
              const Icon(Icons.school_outlined, color: DS.accent),
              const SizedBox(width: 8),
              Text('Reporte Moodle', style: DS.h2),
              const Spacer(),
              Text(nowStr, style: DS.pDim),
            ],
          ),
          const SizedBox(height: 12),
          // datos
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar opcional: iniciales
              CircleAvatar(
                radius: 24,
                backgroundColor: DS.card,
                child: Text(_iniciales(nombre), style: DS.h2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  runSpacing: 6,
                  spacing: 10,
                  children: [
                    _chip('Nombre', nombre),
                    _chip('Cédula', cedula),
                    _chip('Curso', curso.replaceAll('_', ' ')),
                    _chip('Cursos', '$cursosCount'),
                    _chip('Ítems', '$itemsCount'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: cargando ? null : onActualizar,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DS.primary,
                  foregroundColor: DS.text,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onDescargar,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Descargar PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DS.text,
                  side: BorderSide(color: DS.card.withOpacity(.6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _iniciales(String s) {
    final p = s.trim().split(RegExp(r'\s+'));
    final a = p.isNotEmpty && p.first.isNotEmpty ? p.first[0] : '';
    final b = p.length > 1 && p.last.isNotEmpty ? p.last[0] : '';
    final r = (a + b).toUpperCase();
    return r.isEmpty ? 'U' : r;
  }

  static Widget _chip(String label, String value) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: DS.cardSoft,
        border: Border.all(color: DS.cardSoft.withOpacity(.8)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label:', style: DS.pDim.copyWith(fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            value.replaceAll('_', ' '),
            style: DS.p.copyWith(fontWeight: FontWeight.w700, fontSize: 12),
            softWrap: true,
            overflow: TextOverflow.visible,
            maxLines: null,
          ),
        ],
      ),
    );
  }
}

/// ======= Campo de fecha con DatePicker =======
class _FechaPicker extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPick;

  const _FechaPicker({
    required this.label,
    required this.value,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: DS.pDim),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? now,
                firstDate: DateTime(now.year - 2),
                lastDate: DateTime(now.year + 2),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: DS.primary,
                        surface: DS.card,
                        onSurface: DS.text,
                      ),
                      dialogBackgroundColor: DS.bg,
                    ),
                    child: child!,
                  );
                },
              );
              onPick(picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: DS.cardSoft,
                border: Border.all(color: DS.cardSoft.withOpacity(.8)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value == null
                        ? 'Selecciona fecha'
                        : DateFormat('dd/MM/yyyy').format(value!),
                    style: DS.p,
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: DS.textDim,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ======= Leyenda de calificaciones =======
class _LeyendaCalificaciones extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget bullet(String title, List<String> lines) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(color: DS.text, fontSize: 14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: DS.p.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  ...lines.map((l) => Text(l, style: DS.pDim)).toList(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: DS.cardDeco(),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cómo leer la calificación', style: DS.h2),
          const SizedBox(height: 8),
          bullet('1. Guion ( - )', [
            'Indica que la actividad aún no ha sido calificada por el docente.',
            'La tarea o evaluación está registrada, pero el docente todavía no ingresa la nota.',
          ]),
          bullet('2. Calificación = 0', [
            'El docente revisó la actividad y otorgó la nota mínima.',
            'Suele ocurrir cuando el estudiante no entregó la tarea o evaluación ni en la fecha asignada ni en el plazo extendido.',
          ]),
          bullet('3. Calificación diferente de 0', [
            'Es la nota real obtenida por el estudiante.',
            'Refleja el desempeño de acuerdo con los criterios establecidos.',
          ]),
        ],
      ),
    );
  }
}

/// ======= Card de Curso (oscuro) =======
class _CursoCardDark extends StatelessWidget {
  final Map<String, dynamic> curso;
  final Color headerBg;
  final List Function(List items) onFiltrarItems;

  const _CursoCardDark({
    required this.curso,
    required this.headerBg,
    required this.onFiltrarItems,
  });

  @override
  Widget build(BuildContext context) {
    final fullname = (curso['fullname'] ?? '').toString().replaceAll('_', ' ');
    final shortname = (curso['shortname'] ?? '').toString().replaceAll(
      '_',
      ' ',
    );
    final image = (curso['image'] ?? '') as String?;
    final grades = (curso['grades'] ?? {}) as Map<String, dynamic>;
    final secciones =
        grades.keys.map((k) => k.toString().replaceAll('_', ' ')).toList()
          ..sort();

    return Container(
      decoration: DS.cardDeco(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (image != null && image.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    image,
                    height: 48,
                    width: 48,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: DS.cardSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.menu_book_outlined,
                    color: DS.textDim,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre de curso con wrap
                    Text(
                      fullname,
                      style: DS.h2,
                      softWrap: true,
                      overflow: TextOverflow.visible,
                      maxLines: null,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shortname,
                      style: DS.pDim,
                      softWrap: true,
                      overflow: TextOverflow.visible,
                      maxLines: null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final s in secciones)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _SeccionBlockDark(
                nombre: s,
                // OJO: el map original sigue usando la key sin reemplazo para acceder
                items: onFiltrarItems(
                  (curso['grades'][s.replaceAll(' ', '_')] ?? []) as List,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ======= Bloque de Sección (oscuro) =======
class _SeccionBlockDark extends StatelessWidget {
  final String nombre;
  final List items;

  const _SeccionBlockDark({required this.nombre, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DS.cardSoft,
        border: Border.all(color: DS.cardSoft.withOpacity(.9)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sección ${nombre.replaceAll('_', ' ')}', style: DS.h2),
              Text('Total ítems: ${items.length}', style: DS.pDim),
            ],
          ),
          const SizedBox(height: 8),

          // Tabla
        // Tabla
_TableDark(
  headers: const ['Actividad', 'Nota', 'Máx', 'Fecha', 'Comentario'],
  rows: items.map<List<String>>((it) {
    final itemName = (it['itemName'] ?? '-').toString().replaceAll('_', ' ');
    final raw = it['graderaw'];
    final graderaw = raw == null ? '-' : raw.toString();
    final max = (it['max']?.toString() ?? '-');
    final fechaVal = it['gradedategraded'];
    final fecha = (fechaVal == null || fechaVal.toString().trim().isEmpty)
        ? '-'
        : fechaVal.toString();

    final comentarioPlano = _stripHtml((it['comentario'] ?? '').toString());

    // 🔹 Ahora el comentario será una columna separada
    return [itemName, graderaw, max, fecha, comentarioPlano];
  }).toList(),
),

        ],
      ),
    );
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}

/// ======= Tabla oscura reutilizable =======
class _TableDark extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;

  const _TableDark({required this.headers, required this.rows});

  @override
  Widget build(BuildContext context) {
    final headerStyle = DS.p.copyWith(
      fontWeight: FontWeight.w800,
      fontSize: 12,
    );
    final cellStyle = DS.p.copyWith(fontSize: 13);
    final borderColor = DS.cardSoft.withOpacity(.85);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.2), // Actividad
          1: FlexColumnWidth(0.8), // Nota
          2: FlexColumnWidth(0.8), // Máx
          3: FlexColumnWidth(1.2), // Fecha
          4: FlexColumnWidth(2.0), // Comentario
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder(
          horizontalInside: BorderSide(color: borderColor),
          verticalInside: BorderSide(color: borderColor),
          top: BorderSide(color: borderColor),
          left: BorderSide(color: borderColor),
          right: BorderSide(color: borderColor),
          bottom: BorderSide(color: borderColor),
        ),
        children: [
          // ===== Encabezados =====
          TableRow(
            decoration: const BoxDecoration(color: DS.card),
            children: headers
                .map(
                  (h) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      h,
                      style: headerStyle,
                      textAlign:
                          (h == 'Actividad' || h == 'Comentario')
                              ? TextAlign.left
                              : TextAlign.right,
                    ),
                  ),
                )
                .toList(),
          ),
          // ===== Filas =====
          ...rows.map(
            (cols) => TableRow(
              children: List.generate(cols.length, (i) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    cols[i].replaceAll('_', ' '),
                    style: cellStyle,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    maxLines: null,
                    textAlign:
                        (i == 0 || i == 4) ? TextAlign.left : TextAlign.right,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
