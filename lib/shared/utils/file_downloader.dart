// lib/shared/utils/file_downloader.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

typedef ProgressCallback = void Function(double);

class FileDownloader {
  static Future<String> downloadToAppDocs(
    Uri url, {
    required String filename,
    Map<String, String>? headers,
    ProgressCallback? onProgress,
  }) async {
    final req = http.Request('GET', url);
    if (headers != null) req.headers.addAll(headers);
    final res = await req.send();
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }

    final total = res.contentLength ?? -1;
    int received = 0;
    final bytes = <int>[];
    await for (final chunk in res.stream) {
      bytes.addAll(chunk);
      received += chunk.length;
      if (onProgress != null && total > 0) {
        onProgress(received / total);
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);
    return file.path;
  }

  static Future<void> downloadAndOpen(
    Uri url, {
    required String filename,
    Map<String, String>? headers,
    ProgressCallback? onProgress,
  }) async {
    final path = await downloadToAppDocs(
      url,
      filename: filename,
      headers: headers,
      onProgress: onProgress,
    );
    final res = await OpenFilex.open(path, type: 'application/pdf');
    if (res.type != ResultType.done) {
      throw Exception('No se pudo abrir el PDF: ${res.message}');
    }
  }
}
