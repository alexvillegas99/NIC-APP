import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nic_pre_u/services/auth_service.dart';
import 'package:nic_pre_u/services/asistencia_service.dart';
import 'package:nic_pre_u/shared/utils/file_downloader.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';

/// ===== Item combinado para pintar filas (asistencia + faltas) =====
class DiaItem {
  final String fechaISO;
  final List<String> horas;
  final bool asistio;

  const DiaItem({
    required this.fechaISO,
    required this.horas,
    required this.asistio,
  });
}

class AsistenciaReportScreen extends StatefulWidget {
  const AsistenciaReportScreen({super.key});

  @override
  State<AsistenciaReportScreen> createState() => _AsistenciaReportScreenState();
}

class _AsistenciaReportScreenState extends State<AsistenciaReportScreen> {
  final _auth = AuthService();
  final _svc = AsistenciaService();

  Future<AsistenciaReporte>? _future;

  List<Map<String, dynamic>> _cursos = [];
  String? _cursoSeleccionadoId;
  String _cedula = '';

  @override
  void initState() {
    super.initState();
    _loadInicial();
  }

  /// ===== Carga inicial =====
  Future<void> _loadInicial() async {
    try {
      final user = await _auth.getUser();

      _cedula = (user?['cedula'] ?? '').toString();
      _cursos = List<Map<String, dynamic>>.from(user?['cursos'] ?? []);

      if (_cedula.isEmpty) {
        setState(
          () => _future = Future.error('No se encontró cédula en el usuario'),
        );
        return;
      }

      if (_cursos.isEmpty) {
        setState(() => _future = Future.error('No tienes cursos asignados'));
        return;
      }

      // ✅ Al entrar: selecciona el PRIMER curso del array (solo una vez)
      _cursoSeleccionadoId ??= _cursos.first['_id']?.toString();

      _consultar();
    } catch (e) {
      setState(
        () => _future = Future.error('Error cargando usuario/cursos: $e'),
      );
    }
  }

  /// ===== Consulta asistencia =====
  void _consultar() {
    if (_cedula.isEmpty) {
      setState(() => _future = Future.error('No se encontró cédula'));
      return;
    }

    final cursoId = _cursoSeleccionadoId?.toString();
    if (cursoId == null || cursoId.isEmpty) {
      setState(
        () => _future = Future.error('No se encontró curso seleccionado'),
      );
      return;
    }

    setState(() {
      _future = _svc.getPorCedula(cedula: _cedula, cursoId: cursoId);
    });
  }

  Future<void> _refresh() async => _consultar();

  // ===== Helpers =====

  String _fmtHoras(dynamic raw) {
    if (raw == null) return '—';
    if (raw is List && raw.isNotEmpty) raw = raw.first;
    if (raw is String && raw.contains(':')) {
      final p = raw.split(':');
      if (p.length >= 2) return '${p[0]}:${p[1]}';
    }
    return raw.toString();
  }

  String _fmtFriendlyDate(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat("d 'de' MMMM 'de' y", 'es').format(d).toLowerCase();
  }

  Map<String, dynamic>? get _cursoSeleccionado {
    final id = _cursoSeleccionadoId?.toString();
    if (id == null || id.isEmpty) return null;
    for (final c in _cursos) {
      if ((c['_id']?.toString() ?? '') == id) return c;
    }
    return null;
  }

  String get _cursoNombreSeleccionado =>
      _cursoSeleccionado?['nombre']?.toString() ?? '—';

  Widget _estadoChip(bool asistio) {
    final color = asistio ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.5)),
      ),
      child: Text(
        asistio ? 'Asistió' : 'Faltó',
        style: DS.p.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  /// ✅ Construye lista final (asistencias + faltas) SIN duplicar lógica
  List<DiaItem> _buildItems(AsistenciaReporte data) {
    final registros = data.registros ?? <AsistenciaRegistro>[];
    final faltas = (data.faltas?.diasFaltados ?? const <String>[]).toSet();

    final regPorFecha = <String, AsistenciaRegistro>{
      for (final r in registros) r.fecha: r,
    };

    final items = <DiaItem>[
      for (final r in registros)
        DiaItem(
          fechaISO: r.fecha,
          horas: r.horas,
          asistio: r.horas.isNotEmpty || r.registrosEnElDia > 0,
        ),
      for (final f in faltas)
        if (!regPorFecha.containsKey(f))
          DiaItem(fechaISO: f, horas: const <String>[], asistio: false),
    ];

    items.sort((a, b) => b.fechaISO.compareTo(a.fechaISO));
    return items;
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
            fontWeight: FontWeight.w700,
            color: DS.text,
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(title: Text('Reporte de asistencia', style: DS.h2)),
        body: RefreshIndicator(
          color: DS.primary,
          onRefresh: _refresh,
          child: FutureBuilder<AsistenciaReporte>(
            future: _future,
            builder: (context, s) {
              if (s.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: DS.primary),
                );
              }

              if (s.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error: ${s.error}',
                      style: DS.p.copyWith(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!s.hasData || s.data == null) {
                return Center(
                  child: Text('Sin datos de asistencia aún.', style: DS.pDim),
                );
              }

              final data = s.data!;
              final items = _buildItems(data);

              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  /// ===== HEADER =====
                  _HeaderAsistencia(
                    nombre: data.asistenteNombre ?? '-',
                    cedula: data.cedula,
                    curso: _cursoNombreSeleccionado,
                    porcentaje: data.resumen.porcentajeAsistencia.toDouble(),
                    estado: data.curso.estado ?? '—',
                    cargando: false,
                    onActualizar: _refresh,
                    onDescargar: () async {
                      final cursoId = _cursoSeleccionadoId?.toString() ?? '';
                      if (cursoId.isEmpty) return;

                      final url = _svc.buildPdfUri(
                        data.cedula,
                        cursoId: cursoId,
                      );

                      await FileDownloader.downloadAndOpen(
                        url,
                        filename: 'asistencia_${data.cedula}.pdf',
                      );
                    },
                  ),

                  /// ===== SELECTOR (solo si tiene +1) =====
                  if (_cursos.length > 1)
                    _CursoSelectorCard(
                      cursos: _cursos,
                      cursoSeleccionadoId: _cursoSeleccionadoId,
                      onChanged: (v) {
                        setState(() => _cursoSeleccionadoId = v);
                        _consultar();
                      },
                    ),

                  /// ===== DETALLE =====
                  ...items.map(
                    (it) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Container(
                        decoration: DS.cardDeco(),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                _fmtFriendlyDate(it.fechaISO),
                                style: DS.p.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                it.asistio ? _fmtHoras(it.horas) : '—',
                                textAlign: TextAlign.center,
                                style: DS.pDim,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _estadoChip(it.asistio),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// ✅ Selector refactorizado en widget (tu build queda limpito)
class _CursoSelectorCard extends StatelessWidget {
  final List<Map<String, dynamic>> cursos;
  final String? cursoSeleccionadoId;
  final ValueChanged<String> onChanged;

  const _CursoSelectorCard({
    required this.cursos,
    required this.cursoSeleccionadoId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Container(
        decoration: BoxDecoration(
          color: DS.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DS.primary.withOpacity(.55), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.school_rounded, color: DS.accent, size: 18),
                  const SizedBox(width: 8),
                  Text('Curso', style: DS.p.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: DS.primary.withOpacity(.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: DS.primary.withOpacity(.35)),
                    ),
                    child: Text(
                      '${cursos.length} cursos',
                      style: DS.pDim.copyWith(fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Selecciona el curso para ver el reporte',
                style: DS.pDim.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: DS.cardSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: DS.cardSoft.withOpacity(.9)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: cursoSeleccionadoId,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: DS.text,
                    ),
                    dropdownColor: DS.card,
                    style: DS.p.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: DS.text,
                    ),
                    items: cursos.map<DropdownMenuItem<String>>((c) {
                      final id = c['_id']?.toString() ?? '';
                      final nombre = c['nombre']?.toString() ?? '—';
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Row(
                          children: [
                            const Icon(Icons.bookmark_rounded, color: DS.primary, size: 16),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(nombre, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v == null || v.isEmpty) return;
                      onChanged(v);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _HeaderAsistencia extends StatelessWidget {
  final String nombre;
  final String cedula;
  final String curso;
  final String estado;
  final double porcentaje;
  final bool cargando;
  final VoidCallback onActualizar;
  final VoidCallback onDescargar;

  const _HeaderAsistencia({
    required this.nombre,
    required this.cedula,
    required this.curso,
    required this.porcentaje,
    required this.estado,
    required this.cargando,
    required this.onActualizar,
    required this.onDescargar,
  });

  static String _iniciales(String s) {
    final p = s.trim().split(RegExp(r'\s+'));
    final a = p.isNotEmpty && p.first.isNotEmpty ? p.first[0] : '';
    final b = p.length > 1 && p.last.isNotEmpty ? p.last[0] : '';
    return (a + b).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final nowStr =
        DateFormat('dd/MM/yyyy HH:mm', 'es').format(DateTime.now());

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [DS.primary, DS.primary2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ===== TÍTULO =====
          Row(
            children: [
              const Icon(Icons.fact_check_outlined, color: DS.accent),
              const SizedBox(width: 8),
              Text('Asistencia', style: DS.h2),
              const Spacer(),
              Text(nowStr, style: DS.pDim),
            ],
          ),

          const SizedBox(height: 14),

          /// ===== INFO PRINCIPAL =====
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: DS.card,
                child: Text(
                  _iniciales(nombre),
                  style: DS.h2,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _chip('Nombre', nombre),
                    _chip('Cédula', cedula),
                    _chip('Curso', curso),
                    _chip('Estado', estado),
                    _chip(
                      'Asistencia',
                      '${porcentaje.toStringAsFixed(1)}%',
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          /// ===== ACCIONES =====
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
                onPressed: cargando ? null : onDescargar,
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

  /// ===== CHIP INFO =====
  static Widget _chip(String label, String value) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: DS.cardSoft,
        border: Border.all(color: DS.cardSoft.withOpacity(.8)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: DS.pDim.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '—' : value,
            style: DS.p.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            softWrap: true,
          ),
        ],
      ),
    );
  }
}
