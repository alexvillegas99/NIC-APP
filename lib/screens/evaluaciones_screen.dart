import 'package:flutter/material.dart';
import 'package:nic_pre_u/services/evaluaciones_service.dart';
import 'package:nic_pre_u/services/auth_service.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';
import 'package:nic_pre_u/shared/widgets/nic_header.dart';
import 'package:nic_pre_u/shared/widgets/glass_card.dart';
import 'package:nic_pre_u/shared/widgets/background_shapes.dart';

class EvaluacionesScreen extends StatefulWidget {
  const EvaluacionesScreen({super.key});

  @override
  State<EvaluacionesScreen> createState() => _EvaluacionesScreenState();
}

class _EvaluacionesScreenState extends State<EvaluacionesScreen> {
  final EvaluacionesService _service = EvaluacionesService();
  bool _loading = true;

  Map<String, Map<String, List<Map<String, dynamic>>>> _data = {};

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    try {
      final activas = await _service.existenEvaluacionesActivas();

      if (!activas) {
        setState(() => _loading = false);
        return;
      }

      final response = await _service.obtenerEvaluacionesActivas();

      Map<String, Map<String, List<Map<String, dynamic>>>> resultado = {};

      for (var evaluacion in response) {
        final String evaluacionId = evaluacion["_id"];
        final String nombreEvaluacion = evaluacion["nombre"];

        final estado = await _service.obtenerEstadoEstudiante(
          evaluacionId: evaluacionId,
        );

        Map<String, List<Map<String, dynamic>>> agrupado = {};

        for (var item in estado) {
          final String cursoRaw = item["cursoNombre"] ?? "Sin curso";
          final String curso = cursoRaw
              .replaceAll("_", " ")
              .replaceAll("-", " ");

          final List profesoresList = item["profesores"] ?? [];

          agrupado.putIfAbsent(curso, () => []);

          for (var profesorItem in profesoresList) {
            agrupado[curso]!.add({
              "profesor": profesorItem["profesorNombre"] ?? "Sin nombre",
              "realizada": profesorItem["yaEvaluado"] ?? false,
              "evaluacionId": evaluacionId,
              "cursoNombre": curso,
              "cursoId": item["cursoId"],
            });
          }
        }

        resultado[nombreEvaluacion] = agrupado;
      }

      setState(() {
        _data = resultado;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error cargando evaluaciones")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DS.bg,
      body: Stack(
        children: [
          const BackgroundShapes(),
          Column(
            children: [
              NicHeader(
                title: 'Evaluar Profesores',
                color: DS.orange,
                onBack: () => Navigator.pop(context),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(color: DS.primary),
                      )
                    : _data.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.assignment_turned_in_rounded,
                                    size: 56,
                                    color: DS.textSecondary.withValues(alpha: 0.4)),
                                const SizedBox(height: 12),
                                Text(
                                  'No hay evaluaciones activas',
                                  style: DS.poppins(
                                    size: 15,
                                    weight: FontWeight.w500,
                                    color: DS.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: DS.primary,
                            onRefresh: _cargarTodo,
                            child: ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              children: _data.entries.map((evaluacionEntry) {
                                final nombreEvaluacion = evaluacionEntry.key;
                                final cursos = evaluacionEntry.value;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 12, top: 8),
                                      child: Text(
                                        nombreEvaluacion,
                                        style: DS.poppins(
                                          size: 18,
                                          weight: FontWeight.w700,
                                          color: DS.textPrimary,
                                        ),
                                      ),
                                    ),
                                    ...cursos.entries.map((cursoEntry) {
                                      return _CursoGroupCard(
                                        curso: cursoEntry.key,
                                        profesores: cursoEntry.value,
                                        onEvaluado: (profesorEvaluado) {
                                          setState(() {
                                            profesorEvaluado["realizada"] = true;
                                          });
                                        },
                                      );
                                    }),
                                    const SizedBox(height: 16),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Course Group Card
// ─────────────────────────────────────────────────────────────────────────────

class _CursoGroupCard extends StatelessWidget {
  final String curso;
  final List<Map<String, dynamic>> profesores;
  final Function(Map<String, dynamic>) onEvaluado;

  const _CursoGroupCard({
    required this.curso,
    required this.profesores,
    required this.onEvaluado,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: NicCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: DS.nicGradientVertical,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    curso,
                    style: DS.poppins(
                      size: 16,
                      weight: FontWeight.w700,
                      color: DS.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...profesores.map(
              (prof) =>
                  _ProfesorItem(data: prof, onEvaluado: onEvaluado),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Professor Item
// ─────────────────────────────────────────────────────────────────────────────

class _ProfesorItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final Function(Map<String, dynamic>) onEvaluado;

  const _ProfesorItem({required this.data, required this.onEvaluado});

  @override
  Widget build(BuildContext context) {
    final bool realizada = data["realizada"] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: realizada
              ? null
              : () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CalificarProfesorScreen(
                        evaluacionId: data["evaluacionId"],
                        profesor: data["profesor"],
                        cursoNombre: data["cursoNombre"],
                        cursoId: data["cursoId"],
                      ),
                    ),
                  );

                  if (result == true) {
                    onEvaluado(data);
                  }
                },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: DS.bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: realizada
                        ? DS.success.withValues(alpha: 0.12)
                        : DS.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    realizada
                        ? Icons.check_circle_rounded
                        : Icons.pending_actions_rounded,
                    color: realizada ? DS.success : DS.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data["profesor"],
                        style: DS.poppins(
                          size: 14,
                          weight: FontWeight.w600,
                          color: DS.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        realizada ? 'Evaluado' : 'Pendiente',
                        style: DS.poppins(
                          size: 12,
                          weight: FontWeight.w500,
                          color: realizada ? DS.success : DS.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!realizada)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: DS.textSecondary,
                    size: 15,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Calificar Profesor Screen
// ─────────────────────────────────────────────────────────────────────────────

class CalificarProfesorScreen extends StatefulWidget {
  final String evaluacionId;
  final String profesor;
  final String cursoNombre;
  final String cursoId;

  const CalificarProfesorScreen({
    super.key,
    required this.evaluacionId,
    required this.profesor,
    required this.cursoNombre,
    required this.cursoId,
  });

  @override
  State<CalificarProfesorScreen> createState() =>
      _CalificarProfesorScreenState();
}

class _CalificarProfesorScreenState extends State<CalificarProfesorScreen> {
  int? calificacion;
  final TextEditingController _obsCtrl = TextEditingController();
  final EvaluacionesService _service = EvaluacionesService();
  final AuthService _authService = AuthService();

  Map<String, dynamic>? _user;
  bool _enviando = false;

  final _opciones = [
    {'value': 5, 'label': 'Excelente', 'asset': 'assets/imagenes/Asset 2.png'},
    {'value': 4, 'label': 'Muy bueno', 'asset': 'assets/imagenes/Asset 3.png'},
    {'value': 3, 'label': 'Regular', 'asset': 'assets/imagenes/Asset 4.png'},
    {'value': 2, 'label': 'Malo', 'asset': 'assets/imagenes/Asset 5.png'},
    {'value': 1, 'label': 'Muy malo', 'asset': 'assets/imagenes/Asset 6.png'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _authService.getUser();
    if (mounted) {
      setState(() => _user = user);
    }
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (calificacion == null || _user == null) return;

    setState(() => _enviando = true);

    try {
      await _service.enviarEvaluacionProfesor(
        evaluacionId: widget.evaluacionId,
        profesor: widget.profesor,
        cursoId: widget.cursoId,
        cursoNombre: widget.cursoNombre,
        calificacion: calificacion!,
        estudianteNombre: _user?["nombre"] ?? "",
        estudianteCedula: _user?["cedula"] ?? "",
        observacion:
            _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error enviando evaluacion")),
      );
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DS.bg,
      body: Stack(
        children: [
          const BackgroundShapes(),
          Column(
            children: [
              NicHeader(
                title: 'Realizar evaluación',
                color: DS.orange,
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Info card
                      NicCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profesor',
                              style: DS.poppins(
                                size: 12,
                                weight: FontWeight.w500,
                                color: DS.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.profesor,
                              style: DS.poppins(
                                size: 16,
                                weight: FontWeight.w700,
                                color: DS.primary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              height: 1,
                              color: DS.bg,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Curso',
                              style: DS.poppins(
                                size: 12,
                                weight: FontWeight.w500,
                                color: DS.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.cursoNombre,
                              style: DS.poppins(
                                size: 14,
                                weight: FontWeight.w500,
                                color: DS.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      Text(
                        'Como calificas al profesor?',
                        textAlign: TextAlign.center,
                        style: DS.poppins(
                          size: 16,
                          weight: FontWeight.w600,
                          color: DS.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Rating options
                      ..._opciones.map((opt) {
                        final selected = calificacion == opt['value'];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => setState(
                                  () => calificacion = opt['value'] as int),
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: selected
                                        ? DS.primary
                                        : Colors.grey.shade200,
                                    width: selected ? 2 : 1,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: DS.primary
                                                .withValues(alpha: 0.15),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.04),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: DS.bg,
                                      foregroundImage: AssetImage(
                                        opt['asset'] as String,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Text(
                                      opt['label'] as String,
                                      style: DS.poppins(
                                        size: 15,
                                        weight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: DS.textPrimary,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (selected)
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          gradient: DS.nicGradient,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 20),

                      // Observation field
                      TextField(
                        controller: _obsCtrl,
                        maxLines: 3,
                        style: DS.poppins(
                          size: 14,
                          color: DS.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Agregar observacion (opcional)',
                          hintStyle: DS.poppins(
                            size: 14,
                            color: DS.textSecondary.withValues(alpha: 0.5),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: DS.primary, width: 1.5),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Submit button
                      AnimatedOpacity(
                        opacity: calificacion != null ? 1.0 : 0.5,
                        duration: const Duration(milliseconds: 200),
                        child: NicGradientButton(
                          text: 'Enviar calificacion',
                          onPressed: calificacion == null || _enviando
                              ? () {}
                              : _enviar,
                          icon: _enviando ? null : Icons.send_rounded,
                        ),
                      ),

                      if (_enviando)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: DS.primary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
