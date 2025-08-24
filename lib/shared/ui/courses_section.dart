// lib/features/courses/ui/courses_section.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nic_pre_u/services/course_service.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';

class CoursesSection extends StatefulWidget {
  final CourseService service;
  final int maxItems;

  const CoursesSection({
    super.key,
    required this.service,
    this.maxItems = 8,
  });

  @override
  State<CoursesSection> createState() => _CoursesSectionState();
}

class _CoursesSectionState extends State<CoursesSection> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
  _future = widget.service.fetchCoursesWithGradesByUsername()
  ..then((list) async {
    await widget.service.saveCoursesWithGrades(list); // 👈 guarda para después
    //validar si se guardar
   
  });

  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _SkeletonHorizontal();
          }
          if (snap.hasError) {
            return _Error(onRetry: () {
              setState(() => _future = widget.service.fetchCoursesWithGradesByUsername());
            });
          }
          final List<dynamic> courses = snap.data ?? [];
          if (courses.isEmpty) return const SizedBox.shrink();

          final preview = courses.take(widget.maxItems).toList();
          const double cardHeight = 190;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tus cursos/clases', style: DS.h2),
                  InkWell(
                    onTap: () => context.push('/home/courses'),
                    child: Row(
                      children: [
                        Text('Ver todos', style: DS.p.copyWith(color: DS.primary)),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward, color: DS.primary, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: cardHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: preview.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final Map<String, dynamic> c = (preview[i] as Map).cast<String, dynamic>();
                    return _CourseCard(
                      course: c,
                      width: _cardWidth(context),
                      onTap: (course) => context.push('/home/courses/${course['id']}', extra: course),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double _cardWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final target = w * 0.60;
    return target.clamp(220.0, 280.0);
  }
}

class _CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final double width;
  final void Function(Map<String, dynamic>) onTap;

  const _CourseCard({
    required this.course,
    required this.width,
    required this.onTap,
  });

  static const _fallbackArts = [
    'https://i.pinimg.com/736x/15/bc/04/15bc04bfc0f824358e48de5a6dc2238d.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    final String title = (course['fullname'] as String?) ?? '';
    final String? img = (course['image'] as String?);
    final String safeImg = (img != null && img.trim().isNotEmpty) ? img : _fallbackArts[0];

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onTap(course),
      child: Ink(
        width: width,
        decoration: DS.cardDeco().copyWith(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 👇 FLEXIBLE: ocupa el alto restante para no desbordar
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  safeImg,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.white10),
                ),
              ),
            ),
            // Texto con padding pequeño (reduce 1–2 px)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DS.p.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonHorizontal extends StatelessWidget {
  const _SkeletonHorizontal();

  @override
  Widget build(BuildContext context) {
    const double h = 190;
    double w = MediaQuery.of(context).size.width * 0.60;
    w = w.clamp(220.0, 280.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(width: 160, height: 16, color: Colors.white10),
            Container(width: 80, height: 14, color: Colors.white10),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => Container(
              width: w,
              decoration: DS.cardDeco().copyWith(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  final VoidCallback onRetry;
  const _Error({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('No se pudieron cargar los cursos', style: DS.p),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }
}
