import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';
import 'package:nic_pre_u/services/course_service.dart';

class CoursesListScreen extends StatefulWidget {
  final CourseService service;
  const CoursesListScreen({super.key, required this.service});

  @override
  State<CoursesListScreen> createState() => _CoursesListScreenState();
}

class _CoursesListScreenState extends State<CoursesListScreen> {
  final TextEditingController _q = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];

  static const _fallbackImg =
      'https://i.pinimg.com/736x/15/bc/04/15bc04bfc0f824358e48de5a6dc2238d.jpg';

  @override
  void initState() {
    super.initState();
    _loadFromSaved();
    _q.addListener(() => _applyFilter(_q.text));
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _loadFromSaved() async {
    try {
      final list = await widget.service.getSavedCoursesWithGrades();
      final typed =
          list.map((e) => (e as Map).cast<String, dynamic>()).toList();
      setState(() {
        _all = typed;
        _filtered = typed;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Error cargando cursos';
      });
    }
  }

  void _applyFilter(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filtered = _all);
      return;
    }
    setState(() {
      _filtered = _all.where((c) {
        final title = (c['fullname'] as String? ?? '').toLowerCase();
        final short = (c['shortname'] as String? ?? '').toLowerCase();
        return title.contains(q) || short.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DS.bg,
      appBar: AppBar(
        backgroundColor: DS.card,
         // 👇 Hace la flecha (y otros iconos) en blanco
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Todos los cursos', style: TextStyle(color: Colors.white),),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: DS.p))
              : Column(
                  children: [
                    // Buscador
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        controller: _q,
                        style: DS.p,
                        decoration: InputDecoration(
                          hintText: 'Buscar curso…',
                          hintStyle: DS.pDim,
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: DS.card,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),

                    // Lista
                    Expanded(
                      child: _filtered.isEmpty
                          ? Center(
                              child: Text(
                                _q.text.isEmpty
                                    ? 'No hay cursos guardados'
                                    : 'No hay resultados para “${_q.text}”',
                                style: DS.p,
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final c = _filtered[i];
                                final title =
                                    (c['fullname'] as String?) ?? '';
                                final subtitle ='';
                                  // (c['shortname'] as String?) ?? '';
                                final img = (c['image'] as String?)?.trim();
                                final safeImg =
                                    (img != null && img.isNotEmpty)
                                        ? img
                                        : _fallbackImg;

                                return ListTile(
                                  tileColor: DS.card,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: Image.network(
                                        safeImg,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.white10,
                                          child: const Icon(
                                            Icons.menu_book,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(title, style: DS.p),
                                  subtitle: Text(subtitle, style: DS.pDim),
                                  onTap: () => context.push(
                                    '/home/courses/${c['id']}',
                                    extra: c, // pasamos el curso completo
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
