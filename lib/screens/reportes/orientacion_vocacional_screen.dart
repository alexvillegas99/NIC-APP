import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nic_pre_u/services/auth_service.dart';
import 'package:nic_pre_u/services/asistentes_service.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';
import 'package:nic_pre_u/shared/utils/file_downloader.dart';

// ===================== Helpers seguros + logging visible =====================

/// Log que imprime en cualquier modo (debug/profile/release)
void logAlways(String label, Object? value) {
  final ts = DateTime.now().toIso8601String();
  // ignore: avoid_print
  print('[$ts] $label -> $value');
}

/// Convierte cualquier Map con claves dinámicas a Map<String, dynamic>
Map<String, dynamic> mapKeysToString(dynamic raw) {
  if (raw is Map) {
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }
  return <String, dynamic>{};
}

/// Si es List de Map, normaliza; si es Map único, lo envuelve en lista; si no, []
List<Map<String, dynamic>> asListOfStringKeyedMaps(dynamic payload) {
  if (payload == null) return const [];
  if (payload is List) {
    return payload
        .where((e) => e is Map)
        .map((e) => mapKeysToString(e as Map))
        .toList();
  }
  if (payload is Map) {
    return [mapKeysToString(payload)];
  }
  logAlways('asListOfStringKeyedMaps: payload inesperado', {
    'runtimeType': payload.runtimeType.toString(),
    'value': payload,
  });
  return const [];
}

// ============================================================================

class OVScreen extends StatefulWidget {
  const OVScreen({super.key});

  @override
  State<OVScreen> createState() => _OVScreenState();
}

class _OVScreenState extends State<OVScreen> {
  final _auth = AuthService();
  final _svc  = AsistentesService();

  bool _cargando = false;
  String? _error;

  String _cedula = '-';
  String _nombre = '-';
  String _cursoNombre = '-';

  Map<String, dynamic> _ov = <String, dynamic>{}; // orientacionVocacional completo

  @override
  void initState() {
    super.initState();
    _load();
  }

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
          backgroundColor: const Color(0xFF111320),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.8, color: Color(0xFF7C3AED)),
              ),
              SizedBox(width: 14),
              Flexible(
                child: Text('Procesando...', style: TextStyle(color: Colors.white, fontSize: 14)),
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
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _load() async {
    setState(() { _cargando = true; _error = null; });
    logAlways('OVScreen._load', 'start');

    try {
      final user = await _auth.getUser();
      logAlways('OVScreen.user', user);

      final cedula = (user?['cedula'] ?? '').toString();
      logAlways('OVScreen.cedula', cedula);

      if (cedula.isEmpty) {
        setState(() {
          _error = 'No hay cédula en la sesión.';
          _cargando = false;
        });
        return;
      }

      // guarda datos base para header
      _cedula = cedula;
      _nombre = (user?['nombre'] ?? user?['name'] ?? '-').toString();
      _cursoNombre = (user?['cursoNombre'] ?? '-').toString();

      // trae asistente; si el servicio devuelve lista, toma el primero
      final lista = await _svc.fetchAsistentesPorCedula();
      logAlways('OVScreen.fetch.resultType', lista.runtimeType.toString());
      logAlways('OVScreen.fetch.length', lista.length);

      final Map<String, dynamic> asistente = (lista.isNotEmpty)
          ? mapKeysToString(lista.first)
          : <String, dynamic>{};

      logAlways('OVScreen.asistente.keys', asistente.keys.toList());

      final dynamic ovRaw = asistente['orientacionVocacional'];
      _ov = mapKeysToString(ovRaw);

      logAlways('OVScreen._ov.snapshot', {
        'etapaActual': _ov['etapaActual'],
        'tienePrimera': _ov['primera'] is Map,
        'tieneSegunda': _ov['segunda'] is Map,
        'tieneTercera': _ov['tercera'] is Map,
        'tieneCuarta' : _ov['cuarta']  is Map,
        'siguienteCitaISO': _ov['siguienteCitaISO'],
      });

      setState(() { _cargando = false; });
      logAlways('OVScreen._load', 'done');
    } catch (e, st) {
      logAlways('OVScreen.ERROR', {'e': e.toString(), 'stack': st.toString()});
      setState(() {
        _error = 'No se pudo cargar OV: $e';
        _cargando = false;
      });
    }
  }

  // ===== helpers =====
  String _fmtDateTime(dynamic v) {
    if (v == null) return '—';
    try {
      final d = (v is DateTime) ? v : DateTime.parse(v.toString());
      return DateFormat('dd/MM/yyyy HH:mm', 'es').format(d);
    } catch (_) {
      return v.toString();
    }
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    try {
      final d = (v is DateTime) ? v : DateTime.parse(v.toString());
      return DateFormat('dd/MM/yyyy', 'es').format(d);
    } catch (_) {
      return v.toString();
    }
  }

  String _etapaLabel(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'PRIMERA': return 'Primera cita';
      case 'SEGUNDA': return 'Segunda cita';
      case 'TERCERA': return 'Tercera cita';
      case 'CUARTA':  return 'Cuarta cita';
      case 'SIN_CITA': return 'Sin cita asignada';
      default: return raw ?? '—';
    }
  }

  String _estadoLabel(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'EN_PROCESO':     return 'En proceso';
      case 'COMPLETA':       return 'Completa';
      case 'NO_ASISTE':      return 'No asiste';
      case 'REAGENDAMIENTO': return 'Reagendamiento';
      case '':               return '—';
      default:               return raw ?? '—';
    }
  }

  Color _estadoColor(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'COMPLETA':       return const Color(0xFF22C55E);
      case 'EN_PROCESO':     return const Color(0xFFF59E0B);
      case 'REAGENDAMIENTO': return const Color(0xFFA78BFA);
      case 'NO_ASISTE':      return const Color(0xFFEF4444);
      default:               return DS.textDim;
    }
  }

  @override
  Widget build(BuildContext context) {
    final etapaActual = _ov['etapaActual'];
    final siguienteCita = _ov['siguienteCitaISO'];

    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: DS.bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: DS.bg,
          elevation: 0,
          iconTheme: IconThemeData(color: DS.text),
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: DS.text),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: Text('Orientación vocacional', style: DS.h2),
        ),
        body: RefreshIndicator(
          color: DS.primary,
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _HeaderOV(
                nombre: _nombre,
                cedula: _cedula,
                curso: _cursoNombre,
                etapaActual: _etapaLabel(etapaActual?.toString()),
                proximaCita: _fmtDateTime(siguienteCita),
                cargando: _cargando,
                onActualizar: _load,
                onDescargar: () async {
                  // URL del PDF OV (Nest: GET /api/asistentes/ov/:cedula)
                  final url = _svc.buildOvPdfUri(_cedula);

                  try {
                    await _runWithLoader(
                      message: 'Descargando PDF…',
                      task: () => FileDownloader.downloadAndOpen(
                        url,
                        filename: 'ficha_ov_${_cedula}.pdf',
                        // headers: {'Authorization': 'Bearer ${await _auth.getToken()}'}, // ← si tu API lo pide
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('No se pudo abrir el PDF: $e')),
                    );
                  }
                },
              ),

              if (_cargando) const LinearProgressIndicator(minHeight: 2),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ),

              const SizedBox(height: 8),

              // Tarjetas por etapa
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _EtapaCard(
                  titulo: 'Primera cita',
                  data: mapKeysToString(_ov['primera']),
                  fmtDate: _fmtDateTime,
                  estadoLabel: _estadoLabel,
                  estadoColor: _estadoColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _EtapaCard(
                  titulo: 'Segunda cita',
                  data: mapKeysToString(_ov['segunda']),
                  fmtDate: _fmtDateTime,
                  estadoLabel: _estadoLabel,
                  estadoColor: _estadoColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _EtapaCard(
                  titulo: 'Tercera cita',
                  data: mapKeysToString(_ov['tercera']),
                  fmtDate: _fmtDateTime,
                  estadoLabel: _estadoLabel,
                  estadoColor: _estadoColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: _EtapaCard(
                  titulo: 'Cuarta cita',
                  data: mapKeysToString(_ov['cuarta']),
                  fmtDate: _fmtDateTime,
                  estadoLabel: _estadoLabel,
                  estadoColor: _estadoColor,
                ),
              ),

              // Leyenda breve de estados
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Container(
                  decoration: DS.cardDeco(),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cómo leer los estados', style: DS.h2),
                      const SizedBox(height: 8),
                      _bullet('En proceso', 'La cita está creada y pendiente de ejecutarse.'),
                      _bullet('Completa', 'La cita se realizó y fue registrada.'),
                      _bullet('No asiste', 'Se registró inasistencia.'),
                      _bullet('Reagendamiento', 'La cita se movió a otra fecha.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bullet(String title, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: DS.text, fontSize: 14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DS.p.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(text, style: DS.pDim),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderOV extends StatelessWidget {
  final String nombre, cedula, curso, etapaActual, proximaCita;
  final bool cargando;
  final VoidCallback onActualizar;
  final VoidCallback onDescargar;

  const _HeaderOV({
    required this.nombre,
    required this.cedula,
    required this.curso,
    required this.etapaActual,
    required this.proximaCita,
    required this.cargando,
    required this.onActualizar,
    required this.onDescargar,
  });

  static String _iniciales(String s) {
    final p = s.trim().split(RegExp(r'\s+'));
    final a = p.isNotEmpty && p.first.isNotEmpty ? p.first[0] : '';
    final b = p.length > 1 && p.last.isNotEmpty ? p.last[0] : '';
    final r = (a + b).toUpperCase();
    return r.isEmpty ? 'U' : r;
  }

  @override
  Widget build(BuildContext context) {
    final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
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
          // top
          Row(
            children: [
              const Icon(Icons.psychology_alt_outlined, color: DS.accent),
              const SizedBox(width: 8),
              Text('Orientación Vocacional', style: DS.h2),
              const Spacer(),
              Text(nowStr, style: DS.pDim),
            ],
          ),
          const SizedBox(height: 12),

          // chips
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
                  runSpacing: 6,
                  spacing: 10,
                  children: [
                    _chip('Nombre', nombre),
                    _chip('Cédula', cedula),
                    _chip('Curso', curso.replaceAll('_', ' ')),
                    _chip('Etapa actual', etapaActual),
                    _chip('Próxima cita', proximaCita),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // acciones
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
            maxLines: null,
          ),
        ],
      ),
    );
  }
}

class _EtapaCard extends StatelessWidget {
  final String titulo;
  final Map<String, dynamic> data;
  final String Function(dynamic) fmtDate;
  final String Function(String?) estadoLabel;
  final Color Function(String?) estadoColor;

  const _EtapaCard({
    required this.titulo,
    required this.data,
    required this.fmtDate,
    required this.estadoLabel,
    required this.estadoColor,
  });

  @override
  Widget build(BuildContext context) {
    final estado = estadoLabel(data['estado']?.toString());
    final fecha  = data['fechaISO'] == null ? '—' : fmtDate(data['fechaISO']);
/*     final comentario = (data['comentario']?.toString().trim().isEmpty ?? true)
        ? '—'
        : data['comentario'].toString(); */

    final logs = (data['logs'] is List) ? (data['logs'] as List) : const [];

    return Container(
      decoration: DS.cardDeco(),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header etapa
          Row(
            children: [
              Expanded(child: Text(titulo, style: DS.h2)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: estadoColor(data['estado']?.toString()).withOpacity(.15),
                  border: Border.all(color: estadoColor(data['estado']?.toString()).withOpacity(.5)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  estado,
                  style: DS.p.copyWith(
                    fontWeight: FontWeight.w700,
                    color: estadoColor(data['estado']?.toString()),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // info rápida
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _miniInfo('Fecha', fecha),
           //   _miniInfo('Comentario', comentario),
            ],
          ),

          const SizedBox(height: 10),

          // tabla logs
          _LogsTable(logs: logs, fmtDate: fmtDate, estadoLabel: estadoLabel),
        ],
      ),
    );
  }

  Widget _miniInfo(String label, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: DS.cardSoft,
        border: Border.all(color: DS.cardSoft.withOpacity(.85)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label:', style: DS.pDim.copyWith(fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            value,
            style: DS.p,
            softWrap: true,
            overflow: TextOverflow.visible,
            maxLines: null,
          ),
        ],
      ),
    );
  }
}

class _LogsTable extends StatelessWidget {
  final List logs;
  final String Function(dynamic) fmtDate;
  final String Function(String?) estadoLabel;

  const _LogsTable({
    required this.logs,
    required this.fmtDate,
    required this.estadoLabel,
  });

  @override
  Widget build(BuildContext context) {
    final headers = const ['Estado', 'Fecha cita', 'Registrado', 'Comentario'];

    final safeLogs = (logs is List) ? logs : const [];
    final rows = safeLogs.map<List<String>>((l) {
      final m = mapKeysToString(l);
      final est = estadoLabel(m['estado']?.toString());
      final f1  = m['fechaISO'] == null ? '—' : fmtDate(m['fechaISO']);
      final ts  = m['tsISO']    == null ? '—' : fmtDate(m['tsISO']);
      final com = (m['comentario']?.toString().trim().isEmpty ?? true)
          ? '—'
          : m['comentario'].toString();

      return [est, f1, ts, com];
    }).toList();

    final borderColor = DS.cardSoft.withOpacity(.85);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.1),
          1: FlexColumnWidth(1.1),
          2: FlexColumnWidth(1.1),
          3: FlexColumnWidth(2.2),
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
          // header
          TableRow(
            decoration: const BoxDecoration(color: DS.card),
            children: headers.map((h) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                h,
                style: DS.p.copyWith(fontSize: 12, fontWeight: FontWeight.w800),
                textAlign: TextAlign.left,
              ),
            )).toList(),
          ),
          // rows
          ...rows.map((cols) => TableRow(children: [
            for (int i = 0; i < cols.length; i++)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  cols[i],
                  style: DS.p.copyWith(fontSize: 13),
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  maxLines: null,
                ),
              ),
          ])),
        ],
      ),
    );
  }
}
