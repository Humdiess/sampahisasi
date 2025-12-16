import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class TfliteService {
  Interpreter? _interpreter;
  List<String>? _labels;
  bool _isBusy = false;

  bool get isBusy => _isBusy;
  List<String>? get labels => _labels;

  Future<void> loadModel() async {
    try {
      print('TfliteService: Loading model...');
      final options = InterpreterOptions();
      // On Android, typical TFLite usually falls back to CPU/NNAPI if GPU delegate not explicitly added

      _interpreter = await Interpreter.fromAsset(
        'assets/model_unquant.tflite',
        options: options,
      );
      print('TfliteService: Interpreter loaded.');

      // Load labels
      final labelData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelData.split('\n').where((s) => s.isNotEmpty).map((s) {
        final parts = s.split(' ');
        if (parts.length > 1 && int.tryParse(parts[0]) != null) {
          return parts.sublist(1).join(' ');
        }
        return s;
      }).toList();

      print('TfliteService: Model loaded successfully: $_labels');
    } catch (e) {
      print('TfliteService: Error loading model: $e');
    }
  }

  Future<List<double>?> classifyImage(CameraImage cameraImage) async {
    if (_interpreter == null || _isBusy) return null;
    _isBusy = true;

    try {
      // Extract data needed for isolate (copies data)
      final isolateData = _CameraIsolateData(
        width: cameraImage.width,
        height: cameraImage.height,
        planes: cameraImage.planes.map((p) => p.bytes).toList(),
        bytesPerRow: cameraImage.planes.map((p) => p.bytesPerRow).toList(),
        bytesPerPixel: cameraImage.planes.map((p) => p.bytesPerPixel).toList(),
      );

      print('TfliteService: Starting isolate for image processing...');
      // Run computationally expensive image processing in isolate
      final result = await Isolate.run(() {
        return _processInIsolate(isolateData);
      });
      print('TfliteService: Isolate finished. Result valid: ${result != null}');

      if (result == null) {
        _isBusy = false;
        return null;
      }

      print('TfliteService: Running inference...');
      var output = List.filled(1 * 2, 0.0).reshape([1, 2]);

      // Reshape input to [1, 224, 224, 3] to match model expectation
      final input = result.reshape([1, 224, 224, 3]);

      _interpreter!.run(input, output);
      print('TfliteService: Inference done. Output: $output');

      _isBusy = false;
      return List<double>.from(output[0]); // [prob_organic, prob_anorganic]
    } catch (e) {
      print('TfliteService: Error during inference: $e');
      _isBusy = false;
      return null;
    }
  }

  static Float32List? _processInIsolate(_CameraIsolateData data) {
    final image = _convertYUV420ToImage(data);
    if (image == null) return null;

    final resized = img.copyResize(image, width: 224, height: 224);

    // Convert to Float32 List [1, 224, 224, 3]
    var convertedBytes = Float32List(1 * 224 * 224 * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (var i = 0; i < 224; i++) {
      for (var j = 0; j < 224; j++) {
        var pixel = resized.getPixel(j, i);
        buffer[pixelIndex++] = (pixel.r / 127.5) - 1.0;
        buffer[pixelIndex++] = (pixel.g / 127.5) - 1.0;
        buffer[pixelIndex++] = (pixel.b / 127.5) - 1.0;
      }
    }
    return convertedBytes;
  }

  static img.Image? _convertYUV420ToImage(_CameraIsolateData data) {
    final width = data.width;
    final height = data.height;
    if (data.planes.length < 3) return null; // Ensure YUV

    final yRowStride = data.bytesPerRow[0];
    final uvRowStride = data.bytesPerRow[1];
    final uvPixelStride = data.bytesPerPixel[1] ?? 1;

    final image = img.Image(width: width, height: height);

    final yBytes = data.planes[0];
    final uBytes = data.planes[1];
    final vBytes = data.planes[2];

    for (var w = 0; w < width; w++) {
      for (var h = 0; h < height; h++) {
        final uvIndex =
            uvPixelStride * (w / 2).floor() + uvRowStride * (h / 2).floor();
        // formula for index might vary, typically:
        final yIndex = h * yRowStride + w;

        final y = yBytes[yIndex];
        final u = uBytes[uvIndex];
        final v = vBytes[uvIndex];

        int r = (y + (1.370705 * (v - 128))).toInt();
        int g = (y - (0.337633 * (u - 128)) - (0.698001 * (v - 128))).toInt();
        int b = (y + (1.732446 * (u - 128))).toInt();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        image.setPixelRgb(w, h, r, g, b);
      }
    }
    return image;
  }

  void dispose() {
    _interpreter?.close();
  }
}

class _CameraIsolateData {
  final int width;
  final int height;
  final List<Uint8List> planes;
  final List<int> bytesPerRow;
  final List<int?> bytesPerPixel;

  _CameraIsolateData({
    required this.width,
    required this.height,
    required this.planes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
  });
}
