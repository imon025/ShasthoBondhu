import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SkinHistoryItem {
  final String id;
  final String label;
  final double confidence;
  final DateTime dateTime;

  SkinHistoryItem({
    required this.id,
    required this.label,
    required this.confidence,
    required this.dateTime,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'confidence': confidence,
    'dateTime': dateTime.toIso8601String(),
  };

  factory SkinHistoryItem.fromJson(Map<String, dynamic> json) => SkinHistoryItem(
    id: json['id'],
    label: json['label'],
    confidence: json['confidence'].toDouble(),
    dateTime: DateTime.parse(json['dateTime']),
  );
}

class SkinHistoryService {
  static const String _key = 'skin_history';

  Future<void> saveResult(SkinHistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList(_key) ?? [];
    history.insert(0, jsonEncode(item.toJson()));
    
    // Keep only last 50 items to save space
    if (history.length > 50) {
      history.removeRange(50, history.length);
    }
    
    await prefs.setStringList(_key, history);
  }

  Future<List<SkinHistoryItem>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList(_key) ?? [];
    return history.map((e) => SkinHistoryItem.fromJson(jsonDecode(e))).toList();
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
      'type': 'Skin Disease',
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
