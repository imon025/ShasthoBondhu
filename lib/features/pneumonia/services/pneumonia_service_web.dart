
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'pneumonia_service_base.dart';

/// Top-level function for background image processing on Web
Future<Map<String, dynamic>> _processWebHeuristic(Map<String, dynamic> params) async {
  final Uint8List imageBytes = params['bytes'];
  final imageData = img.decodeImage(imageBytes);
  bool isLikelyXray = true;
  
  if (imageData != null) {
    int colorPixels = 0;
    final int sampleCount = 50;
    for (int i = 0; i < sampleCount; i++) {
      final x = (i * 13) % imageData.width;
      final y = (i * 17) % imageData.height;
      final pixel = imageData.getPixel(x, y);
      if ((pixel.r - pixel.g).abs() > 20 || (pixel.r - pixel.b).abs() > 20) {
        colorPixels++;
      }
    }
    isLikelyXray = colorPixels < (sampleCount * 0.3);
  }

  if (!isLikelyXray) {
    return {
      'label': 'NOT AN X-RAY',
      'confidence': 1.0,
      'is_not_xray': true,
      'warning': 'Not a chest X-ray. Please upload a valid X-ray report.',
    };
  }

  final int hash = imageBytes.length + (imageBytes.isNotEmpty ? imageBytes[0] : 0);
  final bool isNormal = (hash % 2 == 0);
  final double confidence = 0.70 + (hash % 100) / 400.0;
  
  return {
    'label': isNormal ? 'NORMAL' : 'PNEUMONIA',
    'confidence': confidence,
    'is_mock': true,
    'is_not_xray': false,
  };
}

class PneumoniaServiceImpl implements PneumoniaService {
  @override
  bool get isModelLoaded => false;

  @override
  Future<void> loadModel() async {
    debugPrint('Pneumonia detection is running in Heuristic Mode on Web.');
  }

  @override
  Future<Map<String, dynamic>> predict(Uint8List imageBytes) async {
    // Offload to compute to keep Chrome responsive
    return await compute(_processWebHeuristic, {'bytes': imageBytes});
  }

  @override
  void dispose() {}
}

PneumoniaService getService() => PneumoniaServiceImpl();
