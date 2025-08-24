// lib/features/courses/data/course.dart
class Course {
  final int id;
  final String shortname;
  final String fullname;
  final String? courseimage;

  Course({
    required this.id,
    required this.shortname,
    required this.fullname,
    this.courseimage,
  });

  factory Course.fromMap(Map<String, dynamic> m) => Course(
        id: m['id'] is int ? m['id'] : int.tryParse('${m['id']}') ?? 0,
        shortname: m['shortname'] ?? '',
        fullname: m['fullname'] ?? '',
        courseimage: m['courseimage'] ??
            (m['overviewfiles'] is List && (m['overviewfiles'] as List).isNotEmpty
                ? (m['overviewfiles'][0]['fileurl'] as String?)
                : null),
      );
}
