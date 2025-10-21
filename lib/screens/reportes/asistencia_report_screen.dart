import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nic_pre_u/services/auth_service.dart';
import 'package:nic_pre_u/services/asistencia_service.dart';
import 'package:nic_pre_u/shared/utils/file_downloader.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';

/// ===== Item combinado para pintar filas (asistencia + faltas) =====
class DiaItem {
  final String fechaISO;       // YYYY-MM-DD
  final List<String> horas;    // HH:mm:ss...
  final bool asistio;          // true = asistió, false = faltó
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await _auth.getUser();
    final cedula = (user?['cedula'] ?? '').toString();
    if (cedula.isEmpty) {
      setState(() => _future = Future.error('No se encontró cédula en el usuario'));
      return;
    }
    setState(() {
      _future = _svc.getPorCedula(cedula);
    });
  }

  // ===== Helpers de formato =====

  /// Devuelve HH:mm a partir de List<String> (toma la primera) o String HH:mm:ss
  String _fmtHoras(dynamic raw) {
    if (raw == null) return '—';
    if (raw is List && raw.isNotEmpty) raw = raw.first;
    if (raw is String && raw.contains(':')) {
      final parts = raw.split(':');
      if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    }
    return raw.toString();
  }

  /// Fecha simple dd/MM/yyyy
  String _fmtDate(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    return d != null ? DateFormat('dd/MM/yyyy', 'es').format(d) : iso;
  }

  /// Fecha “viernes 4 de julio 2025”
  String _fmtFriendlyDate(String? iso) {
   if (iso == null || iso.trim().isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final txt = DateFormat("d 'de' MMMM 'de' y", 'es').format(d);
  return txt.toLowerCase();
  }

  Future<void> _refresh() async => _load();

  Future<T> _runWithLoader<T>({
    required String message,
    required Future<T> Function() task,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: DS.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.8, color: DS.primary),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Text(message, style: DS.p.copyWith(color: DS.text)),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );

    try {
      final result = await task();
      return result;
    } finally {
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
    }
  }

  // Chip “Asistió / Faltó”
  Widget _estadoChip(bool asistio) {
    final txt = asistio ? 'Asistió' : 'Faltó';
    final color = asistio ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.15),
        border: Border.all(color: color.withOpacity(.5)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        txt,
        style: DS.p.copyWith(
          fontWeight: FontWeight.w700,
          color: color,
          fontSize: 12,
        ),
      ),
    );
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
        appBar: AppBar(
          leading: const BackButton(),
          title: Text('Reporte de asistencia', style: DS.h2),
        ),
        body: RefreshIndicator(
          color: DS.primary,
          onRefresh: _refresh,
          child: FutureBuilder<AsistenciaReporte>(
            future: _future,
            builder: (context, s) {
              if (s.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: DS.primary));
              }

              if (s.hasError) {
                return Center(
                  child: Text('Error: ${s.error}', style: DS.p.copyWith(color: Colors.redAccent)),
                );
              }

              if (!s.hasData || s.data == null) {
                return Center(
                  child: Text('Sin datos de asistencia aún.', style: DS.pDim),
                );
              }

              final data = s.data!;

              // ================== Construcción de items combinados ==================
              final Map<String, AsistenciaRegistro> regPorFecha = {
                for (final r in data.registros) r.fecha: r
              };

              final Set<String> faltasFechas = {
                ...(data.faltas?.diasFaltados ?? const <String>[])
              };

              // 1) Items de asistencia
              final List<DiaItem> items = [
                for (final r in data.registros)
                  DiaItem(
                    fechaISO: r.fecha,
                    horas: r.horas,
                    asistio: (r.horas.isNotEmpty) || (r.registrosEnElDia > 0),
                  ),
              ];

              // 2) Items de faltas que no estén ya en registros
            for (final f in faltasFechas) {
  if (!regPorFecha.containsKey(f)) {
    items.add(
      DiaItem( // ← sin `const`
        fechaISO: f,
        horas: const <String>[], // esta sí puede ser const
        asistio: false,
      ),
    );
  }
}


              // 3) Ordenar desc por fecha
              items.sort((DiaItem a, DiaItem b) {
                final DateTime? da = DateTime.tryParse(a.fechaISO);
                final DateTime? db = DateTime.tryParse(b.fechaISO);
                if (da == null && db == null) return 0;
                if (da == null) return 1;
                if (db == null) return -1;
                return db.compareTo(da); // más reciente primero
              });

              // ================== UI ==================
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  _HeaderAsistencia(
                    nombre: data.asistenteNombre ?? '-',
                    cedula: data.cedula,
                    curso: data.curso.nombre ?? '-',
                    porcentaje: (data.resumen.porcentajeAsistencia).toDouble(),
                    estado: data.curso.estado ?? '—',
                    cargando: false,
                    onActualizar: _refresh,
                    onDescargar: () async {
                      final url = _svc.buildPdfUri(data.cedula);
                      try {
                        await _runWithLoader(
                          message: 'Descargando PDF…',
                          task: () => FileDownloader.downloadAndOpen(
                            url,
                            filename: 'asistencia_${data.cedula}.pdf',
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('No se pudo abrir el PDF: $e')),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // === Tarjeta de resumen ===
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: DS.cardDeco(),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Resumen general', style: DS.h2),
                          const SizedBox(height: 8),
                          Text(
                            'Días asistidos: ${data.resumen.diasConAsistencia} / ${data.curso.diasActuales ?? 0}',
                            style: DS.p,
                          ),
                          Text(
                            'Porcentaje: ${data.resumen.porcentajeAsistencia.toStringAsFixed(1)}%',
                            style: DS.p,
                          ),
                          if (data.resumen.ultimaFecha != null)
                            Text(
                              'Último registro: ${_fmtFriendlyDate(data.resumen.ultimaFecha)}',
                              style: DS.pDim,
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // === Detalle por día (Fecha | Hora(s) | Estado) ===
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Detalle por día', style: DS.h2),
                  ),
                  const SizedBox(height: 8),

                  // Encabezado tipo tabla
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: DS.cardDeco(),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text('Fecha', style: DS.p.copyWith(fontWeight: FontWeight.w800)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text('Hora(s)', style: DS.p.copyWith(fontWeight: FontWeight.w800)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Estado',
                              style: DS.p.copyWith(fontWeight: FontWeight.w800),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  ...items.map((DiaItem it) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Container(
                          decoration: DS.cardDeco(),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Columna 1: Fecha (friendly)
                              Expanded(
                                flex: 3,
                                child: Text(
                                  _fmtFriendlyDate(it.fechaISO),
                                  style: DS.p.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              // Columna 2: Hora(s) con sufijo "m"
                              Expanded(
                                flex: 2,
                                child: Text(
                                  it.asistio
                                      ? (it.horas.isEmpty
                                          ? '—'
                                          : (it.horas.length == 1
                                              ? '${_fmtHoras(it.horas)} m'
                                              : '${_fmtHoras(it.horas.first)} m (+${it.horas.length - 1})'))
                                      : '—',
                                  style: DS.pDim,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              // Columna 3: Estado (derecha)
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
                      )),

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

class _HeaderAsistencia extends StatelessWidget {
  final String nombre, cedula, curso, estado;
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
    final nowStr = DateFormat('dd/MM/yyyy HH:mm', 'es').format(DateTime.now());

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
          Row(
            children: [
              const Icon(Icons.fact_check_outlined, color: DS.accent),
              const SizedBox(width: 8),
              Text('Asistencia', style: DS.h2),
              const Spacer(),
              Text(nowStr, style: DS.pDim),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: DS.card,
                child: Text(_iniciales(nombre), style: DS.h2),
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
                    _chip('Asistencia', '${porcentaje.toStringAsFixed(1)}%'),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
          Text('$label:', style: DS.pDim.copyWith(fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '—' : value,
            style: DS.p.copyWith(fontWeight: FontWeight.w700, fontSize: 12),
            softWrap: true,
            overflow: TextOverflow.visible,
          ),
        ],
      ),
    );
  }
}
