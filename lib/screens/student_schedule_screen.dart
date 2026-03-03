import 'package:flutter/material.dart';
import 'package:nic_pre_u/services/asistentes_service.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';

class StudentScheduleScreen extends StatefulWidget {
  const StudentScheduleScreen({super.key});

  @override
  State<StudentScheduleScreen> createState() =>
      _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen> {
  final AsistentesService _service = AsistentesService();
  late Future<List<Map<String, dynamic>>> _futureCursos;

  @override
  void initState() {
    super.initState();
    _futureCursos = _service.fetchCursosPorCedula();
  }

  String cleanName(String name) =>
      name.replaceAll('_', ' ').replaceAll('-', ' ');

  bool tieneHorario(Map<String, dynamic> curso) {
    final h = curso['horario'];
    return h is List && h.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DS.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _futureCursos,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        "Error cargando cursos",
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  final cursos = snapshot.data ?? [];

                  if (cursos.isEmpty) {
                    return const Center(
                      child: Text(
                        "No tienes cursos asignados",
                        style: TextStyle(color: Colors.white60),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: cursos.length,
                    itemBuilder: (_, index) {
                      final curso = cursos[index];
                      final nombre =
                          cleanName(curso['nombre'] ?? '');
                      final hasHorario = tieneHorario(curso);

                      return GestureDetector(
                        onTap: hasHorario
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CourseScheduleDetailScreen(
                                      curso: curso,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        child: Container(
                          margin:
                              const EdgeInsets.only(bottom: 18),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF1F2937),
                                Color(0xFF111827)
                              ],
                            ),
                            borderRadius:
                                BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 12,
                                offset: Offset(0, 6),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombre,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    hasHorario
                                        ? Icons
                                            .arrow_forward_ios
                                        : Icons.close,
                                    color: hasHorario
                                        ? Colors.green
                                        : Colors.redAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    hasHorario
                                        ? "Ver horario"
                                        : "Sin horario disponible",
                                    style: TextStyle(
                                      color: hasHorario
                                          ? Colors.green
                                          : Colors.white60,
                                      fontWeight:
                                          FontWeight.w500,
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 20),
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
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back,
                color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Text(
            "Mis Horarios",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}




class CourseScheduleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> curso;

  const CourseScheduleDetailScreen({
    super.key,
    required this.curso,
  });

  @override
  State<CourseScheduleDetailScreen> createState() =>
      _CourseScheduleDetailScreenState();
}

class _CourseScheduleDetailScreenState
    extends State<CourseScheduleDetailScreen>
    with SingleTickerProviderStateMixin {

  static const List<String> ordenDias = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  late Map<String, List<Map<String, dynamic>>> horario;
  late TabController _tabController;
  late List<String> diasDisponibles;

  // =========================
  // LIMPIAR NOMBRE
  // =========================
  String cleanName(String name) =>
      name.replaceAll('_', ' ').replaceAll('-', ' ');

  // =========================
  // DETECTAR DÍA ACTUAL
  // =========================
  String obtenerDiaActual() {
    final now = DateTime.now();

    switch (now.weekday) {
      case DateTime.monday:
        return 'Lunes';
      case DateTime.tuesday:
        return 'Martes';
      case DateTime.wednesday:
        return 'Miércoles';
      case DateTime.thursday:
        return 'Jueves';
      case DateTime.friday:
        return 'Viernes';
      case DateTime.saturday:
        return 'Sábado';
      case DateTime.sunday:
        return 'Domingo';
      default:
        return 'Lunes';
    }
  }

  // =========================
  // PROCESAR HORARIO
  // =========================
  Map<String, List<Map<String, dynamic>>> procesarHorario(
      List horarioRaw) {

    final Map<String, List<Map<String, dynamic>>> agrupado = {};
    final Set<String> controlDuplicados = {};

    for (var item in horarioRaw) {
      final map = Map<String, dynamic>.from(item);

      final key =
          "${map['Día']}_${map['Hora inicio']}_${map['Hora fin']}_${map['Materia']}_${map['Aula']}_${map['Profesor']}";

      if (controlDuplicados.contains(key)) continue;
      controlDuplicados.add(key);

      final dia = map['Día'] ?? 'Sin día';
      agrupado.putIfAbsent(dia, () => []);
      agrupado[dia]!.add(map);
    }

    for (var dia in agrupado.keys) {
      agrupado[dia]!.sort((a, b) =>
          (a['Hora inicio'] ?? '')
              .compareTo(b['Hora inicio'] ?? ''));
    }

    return Map.fromEntries(
      agrupado.entries.toList()
        ..sort((a, b) => ordenDias
            .indexOf(a.key)
            .compareTo(ordenDias.indexOf(b.key))),
    );
  }

  @override
  void initState() {
    super.initState();

    horario = procesarHorario(
        (widget.curso['horario'] as List?) ?? []);

    diasDisponibles = horario.keys.toList();

    if (diasDisponibles.isEmpty) {
      diasDisponibles = ['Lunes'];
    }

    String hoy = obtenerDiaActual();

    int initialIndex = diasDisponibles.indexOf(hoy);

    if (initialIndex == -1) {
      initialIndex = diasDisponibles.indexOf('Lunes');
      if (initialIndex == -1) initialIndex = 0;
    }

    _tabController = TabController(
      length: diasDisponibles.length,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1C),
      body: SafeArea(
        child: Column(
          children: [

            // ================= HEADER =================
            _buildHeader(context),

            // ================= TABS =================
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(
                  color: Color(0xFF8E2DE2),
                  width: 3,
                ),
              ),
              tabs: diasDisponibles
                  .map((dia) => Tab(text: dia))
                  .toList(),
            ),

            const SizedBox(height: 10),

            // ================= CONTENIDO =================
            Expanded(
              child: horario.isEmpty
                  ? const Center(
                      child: Text(
                        "Sin horario disponible",
                        style:
                            TextStyle(color: Colors.white60),
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: diasDisponibles.map((dia) {
                        final clases = horario[dia] ?? [];

                        return ListView.builder(
                          padding:
                              const EdgeInsets.all(20),
                          itemCount: clases.length,
                          itemBuilder: (context, index) {
                            return _buildClaseItem(
                                clases[index]);
                          },
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= HEADER =================

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 20),
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
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back,
                color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              cleanName(widget.curso['nombre'] ?? ''),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= CLASE ITEM =================

  Widget _buildClaseItem(
      Map<String, dynamic> clase) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F2937), Color(0xFF111827)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 12,
            offset: Offset(0, 6),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [

          // Barra lateral
          Container(
            width: 5,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF8E2DE2),
              borderRadius:
                  BorderRadius.circular(6),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  "${clase['Hora inicio']} - ${clase['Hora fin']}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  clase['Materia'] ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Aula ${clase['Aula'] ?? ''}",
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  clase['Profesor'] ?? '',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
