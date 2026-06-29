// lib/shared/utils/cast.dart
Map<String, dynamic> asStringKeyedMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) {
    return v.map((k, val) => MapEntry(k?.toString() ?? '', val));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> asListOfStringKeyedMaps(dynamic v) {
  if (v is List) {
    return v
        .whereType<Map>()
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  if (v is Map) {
    return [Map<String, dynamic>.from(v)];
  }
  return <Map<String, dynamic>>[];
}
