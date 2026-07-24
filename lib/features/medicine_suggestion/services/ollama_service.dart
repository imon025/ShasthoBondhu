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

  static Stream<String> streamMessage(String message, List<Map<String, String>> history, {String ragContext = ''}) async* {
    // Check for fast basic questions to bypass the AI generation time
    final lowerMessage = message.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    
    final basicResponses = {
      'hello': 'Hi! 👋 How can I help you?',
      'hi': 'Hello! 😊',
      'hey': 'Hey there!',
      'how are you': "I'm doing well! How about you?",
      'how are you doing': "I'm good! Thanks for asking 😊",
      'whats up': 'Not much! Just here to help you.',
      'good morning': 'Good morning! 🌞',
      'good night': 'Good night! 😴',
      'good evening': 'Good evening! 🌙',
      'bye': 'Bye! Take care 👋',
      'see you': 'See you soon!',
      'thank you': "You're welcome!",
      'thanks': 'Happy to help!',
      'ok': '👍',
      'okay': 'Alright!',
      'yes': 'Great!',
      'no': 'Okay 👍',
      'maybe': 'Alright, let me know 😊',
      'who are you': "I'm your AI assistant.",
      'what is your name': "I'm ShasthoBondhu assistant.",
      'are you human': "No, I'm an AI.",
      'are you real': "I'm a virtual assistant.",
      'can you help me': 'Yes! Tell me what you need.',
      'help': "I'm here to help 😊",
      'i need help': 'Sure! What do you need help with?',
      'nice': '😊',
      'cool': 'Glad you liked it!',
      'wow': '😊',
      'hmm': 'Thinking... tell me more.',
      'lol': '😄',
      'haha': '😄',
      'good job': 'Thank you!',
      'well done': 'Appreciate it!',
      'sorry': "It's okay 😊",
      'my bad': 'No problem!',
      'excuse me': 'Yes, how can I help?',
      'please': 'Sure 😊',
      'i dont know': "That's okay, I can help you.",
      'i understand': '👍',
      'i dont understand': 'Let me explain simply.',
      'explain': 'Sure! What should I explain?',
      'tell me': 'Okay, tell me your question.',
      'can you talk': 'Yes, I can chat with you.',
      'are you busy': "No, I'm always ready!",
      'are you free': 'Yes 😊',
      'what can you do': 'I can chat and help answer questions.',
      'nothing': 'Okay 👍',
      'hmm okay': 'Alright!',
      'good': '👍',
      'bad': 'Oh okay...',
      'i am bored': 'Want to chat about something fun?',
      'i am sad': "I'm here if you want to talk.",
      'i am happy': "That's great! 😊",
      'i am angry': "Take a deep breath, I'm here to help.",
      'i am tired': 'You should take some rest.',
      'what time is it': "I can't check live time, but your device can.",
      'what day is it': 'You can check your device calendar.',
      'where are you': "I'm in your app 😊",
      'do you know me': 'Only what you tell me.',
      'remember me': 'I can remember if your app supports memory.',
      'forget it': 'Okay 👍',
      'are you online': 'Yes!',
      'are you offline': "I'm ready whenever you are.",
      'open app': 'Sure!',
      'close app': 'Okay 👋',
      'restart': 'Restarting...',
      'stop': 'Okay.',
      'continue': 'Sure!',
      'next': 'Alright!',
      'back': 'Going back.',
      'save': 'Saved 👍',
      'delete': 'Deleted.',
      'edit': "Sure, let's edit it.",
      'send': 'Sent!',
      'receive': 'Received 👍',
      'confirm': 'Confirmed.',
      'cancel': 'Cancelled.',
      'open': 'Opening...',
      'close': 'Closing...',
      'login': 'Please enter your details.',
      'logout': 'Logged out.',
      'register': "Let's create your account.",
      'sign up': 'Starting signup.',
      'sign in': 'Please sign in.',
      'error': 'Something went wrong.',
      'bug': "I'll try to fix it.",
      'problem': 'Tell me more about it.',
      'issue': "I'm here to help.",
      'fix it': 'Working on it.',
      'update': 'Updating...',
      'done': 'Great!',
      'finish': 'Finished 👍',
      'start': "Let's begin!",
      'wait': 'Okay, waiting...',
      'later': 'Alright!',
      'now': 'Sure!',
      'maybe later': 'Okay 😊',
      'i think': 'Tell me your thoughts.',
      'i guess': 'Alright 👍',
      'nice to meet you': 'Nice to meet you too! 😊',
    };

    if (basicResponses.containsKey(lowerMessage)) {
      final responseText = basicResponses[lowerMessage]!;
      final words = responseText.split(' ');
      
      // Simulate typing delay for a natural streaming feel (word by word)
      for (int i = 0; i < words.length; i++) {
        await Future.delayed(const Duration(milliseconds: 40));
        yield words[i] + (i < words.length - 1 ? ' ' : '');
      }
      return;
    }

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
    
    final systemPrompt = '''Rules:
- Be polite, helpful, and concise.
- Do not diagnose diseases with certainty.
- Suggest basic self-care for common symptoms.
- Recommend seeing a doctor if symptoms are severe, persistent, or emergency-related.
- Never prescribe prescription medicines or dosages.
- If the user asks about a medicine, explain its common uses, common side effects, and general precautions.
- If the user says "hello", "hi", "hey", or similar greetings, greet them warmly.
- If the question is unrelated to health, answer briefly and politely.

RAG Context (User's Clinical History):
${ragContext.isNotEmpty ? ragContext : "No clinical history available."}

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
Assistant: Paracetamol is commonly used to reduce fever and relieve mild to moderate pain such as headaches, toothaches, and muscle aches. Follow the recommended dosage and consult a healthcare professional if you have liver disease or other concerns.''';

    messages.removeWhere((m) => m['role'] == 'system');
    messages.insert(0, {
      'role': 'system',
      'content': systemPrompt,
    });

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
