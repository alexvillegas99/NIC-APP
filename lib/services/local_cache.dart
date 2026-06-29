import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache local sobre SharedPreferences.
/// Guarda cualquier valor JSON-encodable con timestamp.
class LocalCache {
  static const _data = 'nic_c_';
  static const _ts = 'nic_t_';

  /// Guarda [value] con la clave [key].
  static Future<void> set(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_data + key, jsonEncode(value));
    await prefs.setInt(_ts + key, DateTime.now().millisecondsSinceEpoch);
  }

  /// Obtiene el valor guardado para [key]. Retorna null si no existe.
  static Future<dynamic> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_data + key);
    if (str == null) return null;
    try {
      return jsonDecode(str);
    } catch (_) {
      return null;
    }
  }

  /// True si existe cache para [key].
  static Future<bool> has(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_data + key);
  }

  /// Minutos desde que se guardó el cache para [key]. Null si no existe.
  static Future<int?> ageMinutes(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_ts + key);
    if (ts == null) return null;
    return DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ts))
        .inMinutes;
  }

  /// Borra el cache de [key].
  static Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_data + key);
    await prefs.remove(_ts + key);
  }
}
