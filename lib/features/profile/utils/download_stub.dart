Future<void> downloadCsv(String fileName, String csvData) async {
  throw UnsupportedError('Cannot download file without dart:html or dart:io');
}

Future<void> downloadBytes(String fileName, List<int> bytes) async {
  throw UnsupportedError('Cannot download bytes without dart:html or dart:io');
}
