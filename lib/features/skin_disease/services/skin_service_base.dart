import 'dart:typed_data';

abstract class SkinService {
  bool get isModelLoaded;
  Future<void> loadModel();
  Future<Map<String, dynamic>> predict(Uint8List imageBytes);
  void dispose();
}
