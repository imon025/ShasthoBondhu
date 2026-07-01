import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final request = http.Request('POST', Uri.parse('http://127.0.0.1:11434/api/chat'));
  request.headers['Content-Type'] = 'application/json';
  request.body = jsonEncode({
    'model': 'qwen3:4b',
    'messages': [{'role': 'user', 'content': 'hi'}],
    'stream': true,
  });

  try {
    final response = await http.Client().send(request);
    print('Status: ${response.statusCode}');
    
    final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());
    await for (var line in stream) {
      print('Line: $line');
      final data = jsonDecode(line);
      print('Parsed: $data');
      break; // Just need first line
    }
  } catch (e) {
    print('Error: $e');
  }
}
