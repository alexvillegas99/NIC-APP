class GradeItem {
  final int itemId;
  final String itemName;
  final dynamic grade;        // puede venir string o número
  final String? percentage;   // ej. "92.50 %"
  final num? min;
  final num? max;
  final String? gradedAt;     // ISO o null (si luego lo agregas)

  GradeItem({
    required this.itemId,
    required this.itemName,
    this.grade,
    this.percentage,
    this.min,
    this.max,
    this.gradedAt,
  });

  factory GradeItem.fromMap(Map<String, dynamic> m) => GradeItem(
    itemId: m['itemId'] ?? m['itemid'] ?? 0,
    itemName: m['itemName'] ?? m['itemname'] ?? '',
    grade: m['grade'],
    percentage: m['percentage'],
    min: (m['min'] as num?) ?? m['grademin'],
    max: (m['max'] as num?) ?? m['grademax'],
    gradedAt: m['gradedAt'],
  );
}
