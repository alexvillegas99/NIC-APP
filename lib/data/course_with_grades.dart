import 'grade_item.dart';

class CourseWithGrades {
  final int id;
  final String shortname;
  final String fullname;
  final String? image;
  final List<GradeItem> grades;

  CourseWithGrades({
    required this.id,
    required this.shortname,
    required this.fullname,
    this.image,
    required this.grades,
  });

  factory CourseWithGrades.fromMap(Map<String, dynamic> m) => CourseWithGrades(
    id: m['id'] ?? 0,
    shortname: m['shortname'] ?? '',
    fullname: m['fullname'] ?? '',
    image: m['image'],
    grades: (m['grades'] as List? ?? [])
        .map((e) => GradeItem.fromMap(e as Map<String, dynamic>))
        .toList(),
  );
}
