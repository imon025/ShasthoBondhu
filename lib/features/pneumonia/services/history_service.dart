import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PneumoniaHistoryItem {
  final String id;
  final String label;
  final double confidence;
  final DateTime dateTime;
  final String? imagePath; // We might store small thumbnails or just IDs

  PneumoniaHistoryItem({
    required this.id,
    required this.label,
    required this.confidence,
    required this.dateTime,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'confidence': confidence,
    'dateTime': dateTime.toIso8601String(),
    'imagePath': imagePath,
  };

  factory PneumoniaHistoryItem.fromJson(Map<String, dynamic> json) => PneumoniaHistoryItem(
    id: json['id'],
    label: json['label'],
    confidence: json['confidence'].toDouble(),
    dateTime: DateTime.parse(json['dateTime']),
    imagePath: json['imagePath'],
  );
}

class HistoryService {
  static const String _key = 'pneumonia_history';

  Future<void> saveResult(PneumoniaHistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList(_key) ?? [];
    history.insert(0, jsonEncode(item.toJson()));
    
    // Keep only last 50 items to save space
    if (history.length > 50) {
      history.removeRange(50, history.length);
    }
    
    await prefs.setStringList(_key, history);
  }

  Future<List<PneumoniaHistoryItem>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList(_key) ?? [];
    return history.map((e) => PneumoniaHistoryItem.fromJson(jsonDecode(e))).toList();
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // --- Cloud Sync (Supabase) ---

  Future<void> saveToCloud({
    required String patientName,
    required int patientAge,
    required String label,
    required double confidence,
  }) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    await client.from('detection_history').insert({
      'user_id': user.id,
      'patient_name': patientName,
      'patient_age': patientAge,
      'label': label,
      'confidence': confidence,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> fetchCloudHistory() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return [];

    final response = await client
        .from('detection_history')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }
}
