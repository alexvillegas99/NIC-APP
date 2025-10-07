import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

String _hex(Uint8List bytes, [int max = 32]) {
  final b = bytes.take(max).map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');
  return b;
}

Future<String> debugDownloadPdf(Uri url, {String filename = 'asistencia_debug.pdf'}) async {
  if (kIsWeb) throw UnsupportedError('Debug nativo no soportado en Web.');

  // 1) Petición
  final res = await http.get(url);
  print('DEBUG PDF ▶️ GET $url');
  print('DEBUG PDF ▶️ status: ${res.statusCode}');

  // Headers (en backend deberían estar estos)
  final hdrs = Map<String, String>.from(res.headers);
  const interesting = [
    'content-type',
    'content-length',
    'content-disposition',
    'cache-control',
  ];
  for (final h in interesting) {
    if (hdrs.containsKey(h)) {
      print('DEBUG PDF ▶️ header $h: ${hdrs[h]}');
    }
  }

  if (res.statusCode != 200) {
    print('DEBUG PDF ❌ body (text): ${res.body}');
    throw Exception('HTTP ${res.statusCode}');
  }

  final bytes = res.bodyBytes;
  print('DEBUG PDF ▶️ bytes length: ${bytes.length}');
  print('DEBUG PDF ▶️ first 8 bytes hex: ${_hex(bytes, 8)}');

  // 2) Verificación de firma PDF
  // Los PDFs inician con "%PDF"
  final isPdf = bytes.length >= 4 &&
      bytes[0] == 0x25 && // %
      bytes[1] == 0x50 && // P
      bytes[2] == 0x44 && // D
      bytes[3] == 0x46;   // F
  print('DEBUG PDF ▶️ startsWith %PDF ? $isPdf');

  // 3) Guardar local
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  print('DEBUG PDF ▶️ saved at: ${file.path}');

  return file.path;
}
