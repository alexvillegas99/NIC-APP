import 'package:flutter/material.dart';
import '../services/evaluaciones_service.dart';
import '../services/auth_service.dart';
import '../shared/ui/design_system.dart';
import '../shared/widgets/background_shapes.dart';

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
              "cursoId": item["cursoId"], // 🔥 ESTE ES EL IMPORTANTE
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error cargando evaluaciones")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1C),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            const SizedBox(height: 20),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.purple),
                    )
                  : _data.isEmpty
                  ? const Center(
                      child: Text(
                        "No hay evaluaciones activas",
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : RefreshIndicator(
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
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  nombreEvaluacion,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
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
                              const SizedBox(height: 24),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        children: const [
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Evaluar Profesores",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F2937), Color(0xFF111827)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            curso,
            style: const TextStyle(
              color: Color(0xFF8E2DE2),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...profesores.map(
            (prof) => _ProfesorItem(data: prof, onEvaluado: onEvaluado),
          ),
        ],
      ),
    );
  }
}

class _ProfesorItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final Function(Map<String, dynamic>) onEvaluado;

  const _ProfesorItem({required this.data, required this.onEvaluado});

  @override
  Widget build(BuildContext context) {
    final bool realizada = data["realizada"] ?? false;

    return InkWell(
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              realizada ? Icons.check_circle : Icons.pending_actions,
              color: realizada
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFF59E0B),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                data["profesor"],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!realizada)
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white54,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}

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
        observacion: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error enviando evaluación")),
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
      backgroundColor: const Color(0xFF0B0F1C),
      body: Stack(
        children: [
          const BackgroundShapes(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  //////////////////////////////////////////////////////
                  /// HEADER
                  //////////////////////////////////////////////////////
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Realizar evaluación",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  //////////////////////////////////////////////////////
                  /// CARD INFORMACIÓN
                  //////////////////////////////////////////////////////
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Profesor",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.profesor,
                          style: const TextStyle(
                            color: Color(0xFF8E2DE2),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Curso",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.cursoNombre,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  //////////////////////////////////////////////////////
                  /// PREGUNTA
                  //////////////////////////////////////////////////////
                  const Text(
                    "¿Cómo calificas al profesor?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 24),

                  //////////////////////////////////////////////////////
                  /// OPCIONES
                  //////////////////////////////////////////////////////
                  ..._opciones.map((opt) {
                    final selected = calificacion == opt['value'];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () =>
                            setState(() => calificacion = opt['value'] as int),
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2937),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF8E2DE2)
                                  : Colors.white24,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: const Color(0xFF1F2937),
                                foregroundImage: AssetImage(
                                  opt['asset'] as String,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                opt['label'] as String,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 20),

                  //////////////////////////////////////////////////////
                  /// OBSERVACIÓN
                  //////////////////////////////////////////////////////
                  TextField(
                    controller: _obsCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Agregar observación (opcional)",
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1F2937),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  //////////////////////////////////////////////////////
                  /// BOTÓN ENVIAR
                  //////////////////////////////////////////////////////
                  ElevatedButton(
                    onPressed: calificacion == null || _enviando
                        ? null
                        : _enviar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8E2DE2),
                      disabledBackgroundColor: Colors.white12,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _enviando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Enviar calificación",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
