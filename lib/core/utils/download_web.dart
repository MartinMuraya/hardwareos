import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'dart:convert';

void downloadCsv(String csvData, String filename) {
  final bytes = utf8.encode(csvData);
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..style.display = 'none'
    ..download = filename;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
