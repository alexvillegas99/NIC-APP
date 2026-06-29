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
        await widget.service.saveCoursesWithGrades(list);
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
              setState(() =>
                  _future = widget.service.fetchCoursesWithGradesByUsername());
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
                  Text(
                    'Tus cursos',
                    style: DS.poppins(
                      size: 18,
                      weight: FontWeight.w700,
                      color: DS.textPrimary,
                    ),
                  ),
                  InkWell(
                    onTap: () => context.push('/home/courses'),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Ver todos',
                            style: DS.poppins(
                              size: 14,
                              weight: FontWeight.w600,
                              color: DS.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: DS.primary,
                            size: 16,
                          ),
                        ],
                      ),
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
                    final Map<String, dynamic> c =
                        (preview[i] as Map).cast<String, dynamic>();
                    return _CourseCard(
                      course: c,
                      width: _cardWidth(context),
                      onTap: (course) => context.push(
                        '/home/courses/${course['id']}',
                        extra: course,
                      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Course Card
// ─────────────────────────────────────────────────────────────────────────────

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
    final String safeImg =
        (img != null && img.trim().isNotEmpty) ? img : _fallbackArts[0];

    return GestureDetector(
      onTap: () => onTap(course),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: DS.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DS.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      safeImg,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: DS.cardSoft,
                        child: Center(
                          child: Icon(
                            Icons.school_rounded,
                            size: 40,
                            color: DS.textSecondary.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                    // Subtle gradient overlay at bottom of image
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.05),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DS.poppins(
                  size: 14,
                  weight: FontWeight.w600,
                  color: DS.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton Loader
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonHorizontal extends StatefulWidget {
  const _SkeletonHorizontal();

  @override
  State<_SkeletonHorizontal> createState() => _SkeletonHorizontalState();
}

class _SkeletonHorizontalState extends State<_SkeletonHorizontal>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

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
            _shimmerBox(160, 18),
            _shimmerBox(80, 16),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => AnimatedBuilder(
              animation: _shimmerCtrl,
              builder: (context, child) {
                return Container(
                  width: w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment(-1.0 + 2.0 * _shimmerCtrl.value, 0),
                      end: Alignment(1.0 + 2.0 * _shimmerCtrl.value, 0),
                      colors: const [
                        Color(0xFFEEEEEE),
                        Color(0xFFF5F5F5),
                        Color(0xFFEEEEEE),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _shimmerBox(double width, double height) {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _shimmerCtrl.value, 0),
              end: Alignment(1.0 + 2.0 * _shimmerCtrl.value, 0),
              colors: const [
                Color(0xFFEEEEEE),
                Color(0xFFF5F5F5),
                Color(0xFFEEEEEE),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error Widget
// ─────────────────────────────────────────────────────────────────────────────

class _Error extends StatelessWidget {
  final VoidCallback onRetry;
  const _Error({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.cloud_off_rounded,
          size: 40,
          color: DS.textSecondary.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 8),
        Text(
          'No se pudieron cargar los cursos',
          style: DS.poppins(
            size: 14,
            weight: FontWeight.w500,
            color: DS.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(
            'Reintentar',
            style: DS.poppins(
              size: 14,
              weight: FontWeight.w600,
              color: DS.primary,
            ),
          ),
        ),
      ],
    );
  }
}
