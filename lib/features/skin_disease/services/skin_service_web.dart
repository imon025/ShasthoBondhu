
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'skin_service_base.dart';

/// Top-level function for background image processing on Web
class SkinServiceImpl implements SkinService {
  List<String> _labels = [];
  bool _isModelLoaded = false;

  @override
  bool get isModelLoaded => _isModelLoaded;

  @override
  Future<void> loadModel() async {
    try {
      final labelsData = await rootBundle.loadString('assets/models/skin_labels.txt');
      _labels = labelsData.split('\n').where((label) => label.isNotEmpty).toList();
      _isModelLoaded = true;
      debugPrint('Skin Disease detection is running in Mock Mode on Web with ${_labels.length} labels.');
    } catch (e) {
      debugPrint('Error loading skin labels on web: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> predict(Uint8List imageBytes) async {
    if (!_isModelLoaded || _labels.isEmpty) {
      return {
        'label': 'Unknown',
        'confidence': 0.0,
        'error': 'Model labels not loaded',
      };
    }

    // Heuristic/Mock based on image hash
    final int hash = imageBytes.length + (imageBytes.isNotEmpty ? imageBytes[0] : 0);
    final int index = hash % _labels.length;
    final double confidence = 0.65 + (hash % 100) / 300.0;
    
    return {
      'label': _labels[index],
      'confidence': confidence > 0.99 ? 0.99 : confidence,
      'is_mock': true,
    };
  }

  @override
  void dispose() {}
}

SkinService getService() => SkinServiceImpl();
