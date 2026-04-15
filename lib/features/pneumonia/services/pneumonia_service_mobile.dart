import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'pneumonia_service_base.dart';

/// Background processing result
class _ImageProcessResult {
  final Float32List? inputBuffer;
  final bool isLikelyXray;
  final String? error;

  _ImageProcessResult({this.inputBuffer, required this.isLikelyXray, this.error});
}

/// Top-level function for background image processing
_ImageProcessResult _processImageBackground(Uint8List imageBytes) {
  try {
    final imageData = img.decodeImage(imageBytes);
    if (imageData == null) return _ImageProcessResult(isLikelyXray: false, error: 'Invalid image');

    // 1. Grayscale Heuristic (X-ray check)
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
    final isLikelyXray = colorPixels < (sampleCount * 0.3);
    
    if (!isLikelyXray) return _ImageProcessResult(isLikelyXray: false);

    // 2. Resizing & Normalization
    final resizedImage = img.copyResize(imageData, width: 224, height: 224);
    var input = Float32List(1 * 224 * 224 * 3);
    var bufferIndex = 0;
    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        var pixel = resizedImage.getPixel(x, y);
        input[bufferIndex++] = (pixel.r / 255.0);
        input[bufferIndex++] = (pixel.g / 255.0);
        input[bufferIndex++] = (pixel.b / 255.0);
      }
    }
    
    return _ImageProcessResult(inputBuffer: input, isLikelyXray: true);
  } catch (e) {
    return _ImageProcessResult(isLikelyXray: false, error: e.toString());
  }
}

class PneumoniaServiceImpl implements PneumoniaService {
  late Interpreter _interpreter;
  bool _isModelLoaded = false;

  @override
  bool get isModelLoaded => _isModelLoaded;

  @override
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/pneumonia_model.tflite');
      _isModelLoaded = true;
    } catch (e) {
      debugPrint('Error loading model: $e');
      _isModelLoaded = false;
    }
  }

  @override
  Future<Map<String, dynamic>> predict(Uint8List imageBytes) async {
    if (!_isModelLoaded) {
      return {
        'error': 'AI Model not yet initialized. Please wait or restart the app.',
        'is_mock': false,
      };
    }

    // Move HEAVY LIFTING to background isolate
    final processResult = await compute(_processImageBackground, imageBytes);

    if (processResult.error != null) return {'error': processResult.error};
    
    if (!processResult.isLikelyXray) {
      return {
        'label': 'NOT AN X-RAY',
        'confidence': 1.0,
        'is_mock': false,
        'warning': 'Not a chest X-ray. Please upload a valid grayscale chest X-ray report.',
      };
    }

    try {
      final input = processResult.inputBuffer!;
      var output = [List<double>.filled(1, 0.0)];
      _interpreter.run(input.reshape([1, 224, 224, 3]), output);

      double confidence = output[0][0];
      // SWAPPED: If confidence > 0.5, it is NORMAL (based on user observation of reversal)
      String label = confidence > 0.5 ? 'NORMAL' : 'PNEUMONIA';
      double displayConfidence = label == 'NORMAL' ? confidence : 1.0 - confidence;

      return {
        'label': label,
        'confidence': displayConfidence,
        'raw_score': confidence,
        'is_mock': false,
      };
    } catch (e) {
      debugPrint('Prediction error: $e');
      return {'error': 'AI Analysis failed: $e'};
    }
  }

  @override
  void dispose() {
    if (_isModelLoaded) {
      _interpreter.close();
    }
  }
}

PneumoniaService getService() => PneumoniaServiceImpl();
