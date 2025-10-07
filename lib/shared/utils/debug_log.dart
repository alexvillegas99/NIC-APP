// lib/shared/utils/debug_log.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';

void debugLog(String label, Object? value) {
  if (!kDebugMode) return;
  final ts = DateTime.now().toIso8601String();
  String text;
  if (value is String) {
    text = value;
  } else {
    try {
      text = const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      text = value.toString();
    }
  }
  debugPrint('[$ts] $label -> $text');
}

/// Convierte Map con claves dinámicas a Map<String, dynamic>
Map<String, dynamic> mapKeysToString(Map input) {
  return input.map((k, v) => MapEntry(k.toString(), v));
}

/// Normaliza cualquier payload a List<Map<String, dynamic>>
List<Map<String, dynamic>> asListOfStringKeyedMaps(dynamic payload) {
  if (payload == null) return const [];

  if (payload is List) {
    return payload
        .where((e) => e is Map)
        .map((e) => mapKeysToString(e as Map))
        .toList();
  }

  if (payload is Map) {
    return [mapKeysToString(payload)];
  }

  // Si el backend devuelve algo inesperado, lo reportamos pero no rompemos
  debugLog('asListOfStringKeyedMaps: payload inesperado', payload.runtimeType);
  return const [];
}
