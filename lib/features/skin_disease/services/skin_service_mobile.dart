
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'skin_service_base.dart';

/// Background processing result
class _ImageProcessResult {
  final Float32List? inputBuffer;
  final String? error;

  _ImageProcessResult({this.inputBuffer, this.error});
}

/// Top-level function for background image processing
_ImageProcessResult _processImageBackground(Uint8List imageBytes) {
  try {
    final imageData = img.decodeImage(imageBytes);
    if (imageData == null) return _ImageProcessResult(error: 'Invalid image');

    // Resizing & Normalization (MobileNetV2 expects 224x224)
    final resizedImage = img.copyResize(imageData, width: 224, height: 224);
    var input = Float32List(1 * 224 * 224 * 3);
    var bufferIndex = 0;
    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        var pixel = resizedImage.getPixel(x, y);
        // MobileNetV2 preprocessing: (pixel / 127.5) - 1.0
        input[bufferIndex++] = (pixel.r / 127.5) - 1.0;
        input[bufferIndex++] = (pixel.g / 127.5) - 1.0;
        input[bufferIndex++] = (pixel.b / 127.5) - 1.0;
      }
    }
    
    return _ImageProcessResult(inputBuffer: input);
  } catch (e) {
    return _ImageProcessResult(error: e.toString());
  }
}

class SkinServiceImpl implements SkinService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isModelLoaded = false;

  @override
  bool get isModelLoaded => _isModelLoaded;

  @override
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/skin_model.tflite');
      final labelsData = await rootBundle.loadString('assets/models/skin_labels.txt');
      _labels = labelsData.split('\n').where((label) => label.isNotEmpty).toList();
      _isModelLoaded = true;
    } catch (e) {
      debugPrint('Error loading skin model: $e');
      _isModelLoaded = false;
    }
  }

  @override
  Future<Map<String, dynamic>> predict(Uint8List imageBytes) async {
    if (!_isModelLoaded || _interpreter == null) {
      return {
        'error': 'AI Model not yet initialized. Please wait or restart the app.',
        'is_mock': false,
      };
    }

    final processResult = await compute(_processImageBackground, imageBytes);
    if (processResult.error != null) return {'error': processResult.error};
    
    try {
      final input = processResult.inputBuffer!;
      
      // Output shape: [1, num_classes]
      var output = List<double>.filled(_labels.length, 0.0).reshape([1, _labels.length]);
      
      _interpreter!.run(input.reshape([1, 224, 224, 3]), output);

      final probabilities = output[0] as List<double>;
      
      // Find max probability
      double maxProb = 0.0;
      int maxIndex = -1;
      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIndex = i;
        }
      }

      String label = maxIndex != -1 ? _labels[maxIndex] : 'Unknown';

      return {
        'label': label,
        'confidence': maxProb,
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
      _interpreter?.close();
    }
  }
}

SkinService getService() => SkinServiceImpl();
