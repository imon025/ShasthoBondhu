import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<void> downloadCsv(String fileName, String csvData) async {
  final directory = await getApplicationDocumentsDirectory();
  final path = '${directory.path}/$fileName';
  final file = File(path);
  await file.writeAsString(csvData);
}

Future<void> downloadBytes(String fileName, List<int> bytes) async {
  final directory = await getApplicationDocumentsDirectory();
  final path = '${directory.path}/$fileName';
  final file = File(path);
  await file.writeAsBytes(bytes);
}
