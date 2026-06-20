// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

Future<void> downloadCsv(String fileName, String csvData) async {
  final bytes = Uri.encodeComponent(csvData);
  html.AnchorElement(href: 'data:text/csv;charset=utf-8,$bytes')
    ..setAttribute('download', fileName)
    ..click();
}

Future<void> downloadBytes(String fileName, List<int> bytes) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
