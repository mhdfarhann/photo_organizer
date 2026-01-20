// lib/services/ml_service.dart
import 'dart:io';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class MLService {
  Interpreter? _interpreter;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final options = InterpreterOptions();
      
      _interpreter = await Interpreter.fromAsset(
        'assets/models/mobilenet_v2.tflite',
        options: options,
      );
      
      _isInitialized = true;
      print('ML Model loaded successfully');
    } catch (e) {
      print('Error loading model: $e');
      throw Exception('Failed to load ML model: $e');
    }
  }

  Future<List<double>> extractFeatures(String imagePath) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final imageBytes = await File(imagePath).readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);
      
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      img.Image resized = img.copyResize(image, width: 224, height: 224);

      var input = _imageToByteListFloat32(resized);

      var output = List.filled(1280, 0.0).reshape([1, 1280]);

      _interpreter!.run(input, output);

      return List<double>.from(output[0]);
    } catch (e) {
      print('Error extracting features: $e');
      return [];
    }
  }

  List<List<List<List<double>>>> _imageToByteListFloat32(img.Image image) {
    var convertedBytes = List.generate(
      1,
      (batch) => List.generate(
        224,
        (y) => List.generate(
          224,
          (x) {
            var pixel = image.getPixel(x, y);
            return [
              (pixel.r / 255.0 - 0.5) * 2,
              (pixel.g / 255.0 - 0.5) * 2,
              (pixel.b / 255.0 - 0.5) * 2,
            ];
          },
        ),
      ),
    );
    return convertedBytes;
  }

  double calculateCosineSimilarity(List<double> vectorA, List<double> vectorB) {
    if (vectorA.isEmpty || vectorB.isEmpty || vectorA.length != vectorB.length) {
      return 0.0;
    }

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < vectorA.length; i++) {
      dotProduct += vectorA[i] * vectorB[i];
      normA += vectorA[i] * vectorA[i];
      normB += vectorB[i] * vectorB[i];
    }

    if (normA == 0.0 || normB == 0.0) {
      return 0.0;
    }

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}