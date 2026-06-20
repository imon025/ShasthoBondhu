
import 'dart:math' as math;
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

    // 1. Enhanced Heuristics (X-ray vs Not X-ray)
    int colorPixels = 0;
    double totalLum = 0;
    List<double> samples = [];
    final int sampleCount = 100;
    
    for (int i = 0; i < sampleCount; i++) {
      final x = (i * 131) % imageData.width;
      final y = (i * 173) % imageData.height;
      final pixel = imageData.getPixel(x, y);
      
      // Color Check: Medical X-rays are perfectly grayscale
      if ((pixel.r - pixel.g).abs() > 15 || (pixel.r - pixel.b).abs() > 15) {
        colorPixels++;
      }
      
      // Luminance: 0.299R + 0.587G + 0.114B
      double lum = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
      totalLum += lum;
      samples.add(lum);
    }

    final avgLum = totalLum / sampleCount;
    
    // Calculate Standard Deviation (Contrast)
    double varianceSum = 0;
    for (var lum in samples) {
      varianceSum += math.pow(lum - avgLum, 2);
    }
    final stdDev = math.sqrt(varianceSum / sampleCount);

    // Heuristic Logic:
    // - Most pixels should be grayscale (< 20% colored)
    // - Should not be overly bright (avgLum < 210) - Clouds are very bright
    // - Should have characteristic contrast (stdDev > 40) - Clouds are often uniform
    // - Should have some dark regions (avgLum > 30)
    
    final isColorFail = colorPixels > (sampleCount * 0.2);
    final isBrightnessFail = avgLum > 210 || avgLum < 30;
    final isContrastFail = stdDev < 42; 

    final isLikelyXray = !isColorFail && !isBrightnessFail && !isContrastFail;
    
    if (!isLikelyXray) return _ImageProcessResult(isLikelyXray: false);

    // 2. Resizing & Normalization (MobileNetV2 expects 224x224)
    final resizedImage = img.copyResize(imageData, width: 224, height: 224);
    var input = Float32List(1 * 224 * 224 * 3);
    var bufferIndex = 0;
    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        var pixel = resizedImage.getPixel(x, y);
        // MobileNetV2 preprocessing is built into the TFLite model graph,
        // so we need to provide raw pixel values (0.0 to 255.0).
        input[bufferIndex++] = pixel.r.toDouble();
        input[bufferIndex++] = pixel.g.toDouble();
        input[bufferIndex++] = pixel.b.toDouble();
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
      
      // Multi-output map
      // outputs[0] = prediction (1, 1)
      // outputs[1] = heatmap (1, 7, 7, 1)
      var predictionOut = [List<double>.filled(1, 0.0)];
      var heatmapOut = [List.generate(7, (_) => List.generate(7, (_) => List<double>.filled(1, 0.0)))];
      
      var outputs = {
        0: predictionOut,
        1: heatmapOut,
      };

      _interpreter.runForMultipleInputs([input.reshape([1, 224, 224, 3])], outputs);

      double confidence = predictionOut[0][0];
      String label = confidence > 0.5 ? 'PNEUMONIA' : 'NORMAL';
      double displayConfidence = label == 'PNEUMONIA' ? confidence : 1.0 - confidence;

      // Process Heatmap
      final heatmapBytes = await compute(_processHeatmap, heatmapOut[0]);

      return {
        'label': label,
        'confidence': displayConfidence,
        'raw_score': confidence,
        'heatmap': heatmapBytes,
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

/// Top-level function for heatmap image generation
Uint8List _processHeatmap(List<List<List<double>>> rawHeatmap) {
  // 1. Normalize heatmap values to 0-255
  double min = 1000, max = -1000;
  for (var row in rawHeatmap) {
    for (var col in row) {
      if (col[0] < min) min = col[0];
      if (col[0] > max) max = col[0];
    }
  }
  
  final range = max - min;
  final heatmapImage = img.Image(width: 7, height: 7);
  
  for (int y = 0; y < 7; y++) {
    for (int x = 0; x < 7; x++) {
      double val = range == 0 ? 0 : (rawHeatmap[y][x][0] - min) / range;
      // Simple Red-Hot heatmap: High val = Red, Low val = Transparent Blue
      // Here we just store the intensity in the Alpha/Red channels
      int r = (val * 255).toInt();
      int a = (val * 180).toInt(); // Max 180 transparency
      heatmapImage.setPixel(x, y, img.ColorRgba8(r, 0, 0, a));
    }
  }

  // 2. Upsample to 224x224 with smoothing
  final upsampled = img.copyResize(heatmapImage, width: 224, height: 224, interpolation: img.Interpolation.linear);
  return Uint8List.fromList(img.encodePng(upsampled));
}

PneumoniaService getService() => PneumoniaServiceImpl();
