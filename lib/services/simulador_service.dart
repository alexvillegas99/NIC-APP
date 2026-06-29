import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nic_pre_u/services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────────────────────
Color simColor(String? hex, {Color fallback = const Color(0xFF2D7FF9)}) {
  if (hex == null) return fallback;
  var h = hex.trim().replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

const _letters = ['A', 'B', 'C', 'D', 'E', 'F'];
String letterFor(int i) => i < _letters.length ? _letters[i] : '${i + 1}';

/// Logo oficial por universidad (réplica del UNI_LOGOS del web).
/// [mono] = logo lineart que se fuerza a blanco; si es false se preserva su color.
class UniLogo {
  final String asset;
  final bool mono;
  const UniLogo(this.asset, {this.mono = true});
}

const _kUniLogos = <String, UniLogo>{
  'UCE': UniLogo('assets/logos/unis/uce.png', mono: false),
  'UTA': UniLogo('assets/logos/unis/uta.png'),
  'UTA CONOCIMIENTOS': UniLogo('assets/logos/unis/uta.png'),
  'UTA RAZONAMIENTO': UniLogo('assets/logos/unis/uta.png'),
  'UTC': UniLogo('assets/logos/unis/utc.png'),
  'UNACH': UniLogo('assets/logos/unis/unach.png'),
  'ESPOCH': UniLogo('assets/logos/unis/espoch.png'),
  'EPN': UniLogo('assets/logos/unis/epn.png', mono: false),
  'ESPOL': UniLogo('assets/logos/unis/espol.png'),
  'UG': UniLogo('assets/logos/unis/ug.png'),
  'UCUENCA': UniLogo('assets/logos/unis/ucuenca.png'),
  'UC': UniLogo('assets/logos/unis/ucuenca.png'), // alias del catálogo
  'ESPE': UniLogo('assets/logos/unis/espe.png'),
  'UNEMI': UniLogo('assets/logos/unis/unemi.png'),
};

/// Devuelve el logo local de una universidad por su sigla, o null si no hay.
UniLogo? uniLogoFor(String uni) => _kUniLogos[uni.trim().toUpperCase()];

// ─────────────────────────────────────────────────────────────────────────────
//  Modelos
// ─────────────────────────────────────────────────────────────────────────────
class SimSeccion {
  final dynamic id;
  final String nombre;
  final String emoji;
  final String color;
  final int count;
  final int available;

  SimSeccion({
    required this.id,
    required this.nombre,
    required this.emoji,
    required this.color,
    required this.count,
    required this.available,
  });

  factory SimSeccion.fromJson(Map<String, dynamic> j) => SimSeccion(
        id: j['id'],
        nombre: (j['nombre'] ?? '').toString(),
        emoji: (j['emoji'] ?? '📘').toString(),
        color: (j['color'] ?? '#2D7FF9').toString(),
        count: (j['count'] as num? ?? 0).toInt(),
        available: (j['available'] as num? ?? 0).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'emoji': emoji,
        'color': color,
        'count': count,
        'available': available,
      };
}

/// Item del catálogo de simuladores.
class SimCatalogItem {
  final String id;
  final String uni;
  final String nombre;
  final String ciudad;
  final String color;
  final String accent;
  final String glyph;
  final String? logoUrl;
  final String releaseStatus; // production | coming_soon | on_demand
  final int totalPreguntas;
  final int totalMin;
  final String dificultad;
  final String? badge;
  final String descripcion;

  final List<SimSeccion> secciones;

  SimCatalogItem({
    required this.id,
    required this.uni,
    required this.nombre,
    required this.ciudad,
    required this.color,
    required this.accent,
    required this.glyph,
    required this.logoUrl,
    required this.releaseStatus,
    required this.totalPreguntas,
    required this.totalMin,
    required this.dificultad,
    required this.badge,
    required this.descripcion,
    required this.secciones,
  });

  bool get disponible => releaseStatus == 'production';
  bool get esEspoch => id.toLowerCase().startsWith('espoch');

  factory SimCatalogItem.fromJson(Map<String, dynamic> j) => SimCatalogItem(
        id: (j['id'] ?? '').toString(),
        uni: (j['uni'] ?? '').toString(),
        nombre: (j['nombre'] ?? '').toString(),
        ciudad: (j['ciudad'] ?? '').toString(),
        color: (j['color'] ?? '#2D7FF9').toString(),
        accent: (j['accent'] ?? '#0F4C8A').toString(),
        glyph: (j['glyph'] ?? '?').toString(),
        logoUrl: (j['logoUrl'] ?? '').toString().isEmpty
            ? null
            : j['logoUrl'].toString(),
        releaseStatus: (j['releaseStatus'] ?? 'production').toString(),
        totalPreguntas: (j['totalPreguntas'] as num? ?? 0).toInt(),
        totalMin: (j['totalMin'] as num? ?? 0).toInt(),
        dificultad: (j['dificultad'] ?? '').toString(),
        badge: (j['badge'] ?? '').toString().isEmpty
            ? null
            : j['badge'].toString(),
        descripcion: (j['descripcion'] ?? '').toString(),
        secciones: ((j['secciones'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => SimSeccion.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  /// Round-trip con [fromJson] — para cachear el "último simulador" del home.
  Map<String, dynamic> toJson() => {
        'id': id,
        'uni': uni,
        'nombre': nombre,
        'ciudad': ciudad,
        'color': color,
        'accent': accent,
        'glyph': glyph,
        'logoUrl': logoUrl,
        'releaseStatus': releaseStatus,
        'totalPreguntas': totalPreguntas,
        'totalMin': totalMin,
        'dificultad': dificultad,
        'badge': badge,
        'descripcion': descripcion,
        'secciones': secciones.map((s) => s.toJson()).toList(),
      };
}

/// Una opción de respuesta (A/B/C/D).
class SimOption {
  final String letra;
  final String html; // contenido (html o texto plano)

  SimOption({required this.letra, required this.html});
}

/// Una pregunta del simulador.
class SimQuestion {
  final dynamic id;
  final dynamic sectionId;
  final String sectionName;
  final String text; // enunciado HTML
  final List<SimOption> options;
  final String correct; // "A".."D"
  final int? difficulty; // 1,2,3 (ESPOCH)
  final String? quotaTag;

  SimQuestion({
    required this.id,
    required this.sectionId,
    required this.sectionName,
    required this.text,
    required this.options,
    required this.correct,
    this.difficulty,
    this.quotaTag,
  });

  factory SimQuestion.fromJson(Map<String, dynamic> j) {
    final rawOpts = (j['options'] as List?) ?? const [];
    final opts = <SimOption>[];
    for (var i = 0; i < rawOpts.length; i++) {
      final o = rawOpts[i];
      String html;
      if (o is String) {
        html = o;
      } else if (o is Map) {
        html = (o['html'] ?? o['text'] ?? '').toString();
      } else {
        html = o.toString();
      }
      opts.add(SimOption(letra: letterFor(i), html: html));
    }
    return SimQuestion(
      id: j['id'],
      sectionId: j['sectionId'],
      sectionName: (j['sectionName'] ?? '').toString(),
      text: (j['text'] ?? '').toString(),
      options: opts,
      correct: (j['correct'] ?? '').toString().toUpperCase().trim(),
      difficulty: (j['difficulty'] as num?)?.toInt(),
      quotaTag: (j['quotaTag'] ?? '').toString().isEmpty
          ? null
          : j['quotaTag'].toString(),
    );
  }
}

/// Metadatos del simulador en curso (devueltos por draw/review).
class SimMeta {
  final String id;
  final String uni;
  final String nombre;
  final String color;
  final String accent;
  final String glyph;
  final int totalMin;
  final List<SimSeccion> secciones;

  SimMeta({
    required this.id,
    required this.uni,
    required this.nombre,
    required this.color,
    required this.accent,
    required this.glyph,
    required this.totalMin,
    required this.secciones,
  });

  factory SimMeta.fromJson(Map<String, dynamic> j) => SimMeta(
        id: (j['id'] ?? '').toString(),
        uni: (j['uni'] ?? '').toString(),
        nombre: (j['nombre'] ?? '').toString(),
        color: (j['color'] ?? '#2D7FF9').toString(),
        accent: (j['accent'] ?? '#0F4C8A').toString(),
        glyph: (j['glyph'] ?? '?').toString(),
        totalMin: (j['totalMin'] as num? ?? 60).toInt(),
        secciones: ((j['secciones'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => SimSeccion.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// Respuesta de draw (simulador iniciado).
class SimDraw {
  final dynamic attemptId;
  final SimMeta sim;
  final List<SimQuestion> questions;

  SimDraw({required this.attemptId, required this.sim, required this.questions});

  factory SimDraw.fromJson(Map<String, dynamic> j) => SimDraw(
        attemptId: j['attemptId'],
        sim: SimMeta.fromJson(
            Map<String, dynamic>.from(j['sim'] as Map? ?? {})),
        questions: ((j['questions'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => SimQuestion.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// Resultado del submit / de un intento.
class SimResult {
  final dynamic attemptId;
  final num score;
  final num scorePct;
  final int correctCount;
  final int totalQuestions;
  final int durationSeconds;
  final String mode;
  final bool isBest;
  final bool timedOut;

  SimResult({
    required this.attemptId,
    required this.score,
    required this.scorePct,
    required this.correctCount,
    required this.totalQuestions,
    required this.durationSeconds,
    required this.mode,
    required this.isBest,
    required this.timedOut,
  });

  factory SimResult.fromJson(Map<String, dynamic> j) => SimResult(
        attemptId: j['attemptId'],
        score: (j['score'] as num? ?? 0),
        scorePct: (j['scorePct'] as num? ?? 0),
        correctCount: (j['correctCount'] as num? ?? 0).toInt(),
        totalQuestions: (j['totalQuestions'] as num? ?? 0).toInt(),
        durationSeconds: (j['durationSeconds'] as num? ?? 0).toInt(),
        mode: (j['mode'] ?? 'examen').toString(),
        isBest: j['isBest'] == true,
        timedOut: j['timedOut'] == true,
      );
}

/// Item del historial.
class SimHistoryItem {
  final dynamic id;
  final String mode;
  final num scorePct;
  final num score;
  final int correctCount;
  final int totalQuestions;
  final int durationSeconds;
  final String? finishedAt;
  final bool timedOut;
  final bool abandoned;
  final bool isBest;

  SimHistoryItem({
    required this.id,
    required this.mode,
    required this.scorePct,
    required this.score,
    required this.correctCount,
    required this.totalQuestions,
    required this.durationSeconds,
    required this.finishedAt,
    required this.timedOut,
    required this.abandoned,
    required this.isBest,
  });

  factory SimHistoryItem.fromJson(Map<String, dynamic> j, String mode) =>
      SimHistoryItem(
        id: j['id'],
        mode: mode,
        scorePct: (j['scorePct'] as num? ?? 0),
        score: (j['score'] as num? ?? 0),
        correctCount: (j['correctCount'] as num? ?? 0).toInt(),
        totalQuestions: (j['totalQuestions'] as num? ?? 0).toInt(),
        durationSeconds: (j['durationSeconds'] as num? ?? 0).toInt(),
        finishedAt: j['finishedAt']?.toString(),
        timedOut: j['timedOut'] == true,
        abandoned: j['abandoned'] == true,
        isBest: j['isBest'] == true,
      );
}

class SimHistory {
  final List<SimHistoryItem> examen;
  final List<SimHistoryItem> entrenamiento;
  SimHistory({required this.examen, required this.entrenamiento});

  bool get vacio => examen.isEmpty && entrenamiento.isEmpty;
}

/// Revisión de un intento (preguntas + respuestas dadas).
class SimReview {
  final dynamic attemptId;
  final SimMeta sim;
  final List<SimQuestion> questions;
  final SimResult result;
  final List<String?> answers; // respuesta dada por pregunta (en orden)

  SimReview({
    required this.attemptId,
    required this.sim,
    required this.questions,
    required this.result,
    required this.answers,
  });

  factory SimReview.fromJson(Map<String, dynamic> j) {
    final resultMap = Map<String, dynamic>.from(j['result'] as Map? ?? {});
    final answers = ((resultMap['answers'] as List?) ?? const [])
        .map((e) => e?.toString())
        .toList();
    return SimReview(
      attemptId: j['attemptId'],
      sim: SimMeta.fromJson(Map<String, dynamic>.from(j['sim'] as Map? ?? {})),
      questions: ((j['questions'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => SimQuestion.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      result: SimResult.fromJson({...resultMap, 'attemptId': j['attemptId']}),
      answers: answers,
    );
  }
}

/// Excepción cuando el estudiante se queda sin intentos (402 / NO_ATTEMPTS).
class SinIntentosException implements Exception {
  final String mensaje;
  SinIntentosException([this.mensaje = 'Sin intentos disponibles']);
  @override
  String toString() => mensaje;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Servicio
// ─────────────────────────────────────────────────────────────────────────────
class SimuladorService {
  final String base = dotenv.env['API_URL'] ?? '';
  final AuthService _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  dynamic _decode(http.Response res) {
    if (res.body.isEmpty) return null;
    return json.decode(res.body);
  }

  /// GET /simulador/catalog
  Future<List<SimCatalogItem>> catalog() async {
    final uri = Uri.parse('$base/simulador/catalog');
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode} al cargar el catálogo');
    }
    final body = _decode(res);
    final data = (body is Map && body['data'] is List)
        ? body['data'] as List
        : (body is List ? body : const []);
    return data
        .whereType<Map>()
        .map((e) => SimCatalogItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// GET /simulador/espoch/carreras (público)
  Future<Map<String, dynamic>> espochCarreras() async {
    final uri = Uri.parse('$base/simulador/espoch/carreras');
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode} al cargar carreras ESPOCH');
    }
    final body = _decode(res);
    return body is Map ? Map<String, dynamic>.from(body) : {};
  }

  /// POST /simulador/draw
  Future<SimDraw> draw({required String testType, String? careerId}) async {
    final uri = Uri.parse('$base/simulador/draw');
    final res = await http.post(
      uri,
      headers: await _headers(),
      body: json.encode({
        'testType': testType,
        if (careerId != null) 'careerId': careerId,
      }),
    );

    if (res.statusCode == 402) throw SinIntentosException();
    if (res.statusCode != 200 && res.statusCode != 201) {
      final body = res.body;
      if (body.contains('NO_ATTEMPTS') || body.contains('Sin intentos')) {
        throw SinIntentosException();
      }
      throw Exception('Error ${res.statusCode} al iniciar el simulador');
    }
    return SimDraw.fromJson(Map<String, dynamic>.from(_decode(res) as Map));
  }

  /// POST /simulador/submit
  Future<SimResult> submit({
    required dynamic attemptId,
    required List<Map<String, dynamic>> answers, // {questionId, selected}
    required int durationSeconds,
    required String mode,
    bool timedOut = false,
  }) async {
    final uri = Uri.parse('$base/simulador/submit');
    final res = await http.post(
      uri,
      headers: await _headers(),
      body: json.encode({
        'attemptId': attemptId,
        'answers': answers,
        'durationSeconds': durationSeconds,
        'mode': mode,
        'timedOut': timedOut,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Error ${res.statusCode} al enviar el simulador');
    }
    return SimResult.fromJson(
        Map<String, dynamic>.from(_decode(res) as Map));
  }

  /// GET /simulador/history?testType=X
  Future<SimHistory> history(String testType) async {
    final uri = Uri.parse('$base/simulador/history?testType=$testType');
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) {
      return SimHistory(examen: const [], entrenamiento: const []);
    }
    final body = _decode(res);
    if (body is! Map) {
      return SimHistory(examen: const [], entrenamiento: const []);
    }
    List<SimHistoryItem> parse(String key) =>
        ((body[key] as List?) ?? const [])
            .whereType<Map>()
            .map((e) =>
                SimHistoryItem.fromJson(Map<String, dynamic>.from(e), key))
            .toList();
    return SimHistory(
      examen: parse('examen'),
      entrenamiento: parse('entrenamiento'),
    );
  }

  /// GET /simulador/attempt/:id/review
  Future<SimReview> review(dynamic attemptId) async {
    final uri = Uri.parse('$base/simulador/attempt/$attemptId/review');
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode} al cargar la revisión');
    }
    return SimReview.fromJson(
        Map<String, dynamic>.from(_decode(res) as Map));
  }

  /// POST /simulador/report-question
  Future<bool> reportQuestion({
    required dynamic questionId,
    String? observation,
    String? simulatorId,
    String? simulatorName,
  }) async {
    final uri = Uri.parse('$base/simulador/report-question');
    final res = await http.post(
      uri,
      headers: await _headers(),
      body: json.encode({
        'questionId': questionId,
        if (observation != null) 'observation': observation,
        if (simulatorId != null) 'simulatorId': simulatorId,
        if (simulatorName != null) 'simulatorName': simulatorName,
      }),
    );
    return res.statusCode == 200 || res.statusCode == 201;
  }
}
