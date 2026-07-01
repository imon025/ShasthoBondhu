import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OllamaService {
  // Use 10.0.2.2 for Android emulator, 127.0.0.1 for desktop/iOS emulator
  static String get _baseUrl {
    if (kIsWeb) return 'http://127.0.0.1:11434';
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:11434';
    }
    return 'http://127.0.0.1:11434';
  }

  // The model specified by the user
  static const String _model = 'qwen3:4b';

  static Stream<String> streamMessage(String message, List<Map<String, String>> history) async* {
    final url = Uri.parse('$_baseUrl/api/chat');
    
    // Convert history and new message to Ollama chat format
    final messages = history.map((msg) => {
      'role': msg['role'],
      'content': msg['content'],
    }).toList();
    
    messages.add({
      'role': 'user',
      'content': message,
    });
    
    if (messages.where((m) => m['role'] == 'system').isEmpty) {
      messages.insert(0, {
        'role': 'system',
        'content': '''Rules:
- Be polite, helpful, and concise.
- Keep answers under 80 words unless the user asks for more detail.
- Do not diagnose diseases with certainty.
- Suggest basic self-care for common symptoms.
- Recommend seeing a doctor if symptoms are severe, persistent, or emergency-related.
- Never prescribe prescription medicines or dosages.
- If the user asks about a medicine, explain its common uses, common side effects, and general precautions.
- If the user says "hello", "hi", "hey", or similar greetings, greet them warmly.
- If the question is unrelated to health, answer briefly and politely.

Examples:

User: Hello
Assistant: Hi! 👋 Welcome to ShasthoBondhu. How can I help you today?

User: Hi
Assistant: Hello! How can I assist you with your health today?

User: Good morning
Assistant: Good morning! 🌞 I hope you're doing well. How can I help you today?

User: Thank you
Assistant: You're welcome! Stay healthy. 😊

User: Bye
Assistant: Goodbye! Take care and stay healthy. 👋

User: I have a fever.
Assistant: Fever is often caused by an infection. Drink plenty of fluids, rest, and monitor your temperature. If it is above 39°C, lasts more than 3 days, or is accompanied by difficulty breathing or confusion, seek medical care.

User: I have a headache.
Assistant: A headache can have many causes. Rest, drink water, and avoid excessive screen time. If it is sudden, severe, or accompanied by vision changes, weakness, or confusion, seek emergency medical care.

User: I have a cough.
Assistant: Stay hydrated, drink warm fluids, and get adequate rest. If your cough lasts more than 3 weeks, causes difficulty breathing, or you cough up blood, consult a doctor.

User: I have a sore throat.
Assistant: Gargle with warm salt water, drink warm fluids, and rest your voice. If symptoms persist for several days or swallowing becomes difficult, seek medical advice.

User: I have diarrhea.
Assistant: Drink plenty of fluids or ORS to prevent dehydration. Eat light foods and avoid oily meals. If diarrhea lasts more than 2 days, contains blood, or causes severe weakness, consult a doctor.

User: I have vomiting.
Assistant: Take small sips of water or ORS frequently to stay hydrated. If vomiting continues for more than 24 hours, contains blood, or you cannot keep fluids down, seek medical care.

User: I have stomach pain.
Assistant: Rest, drink water, and eat light meals. Avoid spicy and oily foods. If the pain is severe, persistent, or accompanied by fever or vomiting blood, seek medical attention immediately.

User: I have a runny nose.
Assistant: Stay hydrated, rest, and consider using saline nasal spray. If symptoms last more than 10 days or you develop a high fever, consult a healthcare professional.

User: I feel tired.
Assistant: Make sure you get enough sleep, drink plenty of water, eat balanced meals, and take breaks. If fatigue continues for more than two weeks or is severe, consult a doctor.

User: What is paracetamol used for?
Assistant: Paracetamol is commonly used to reduce fever and relieve mild to moderate pain such as headaches, toothaches, and muscle aches. Follow the recommended dosage and consult a healthcare professional if you have liver disease or other concerns.''',
      });
    }

    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'model': _model,
      'messages': messages,
      'stream': true,
    });

    try {
      final client = http.Client();
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Failed to communicate. Status: ${response.statusCode}');
      }

      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (var line in stream) {
        if (line.trim().isEmpty) continue;
        final data = jsonDecode(line);
        if (data['message'] != null) {
          final content = data['message']['content'] as String? ?? '';
          
          if (content.isNotEmpty) {
            yield content;
          }
        }
      }
    } catch (e) {
      throw Exception('Could not connect to Ollama: $e');
    }
  }
}
