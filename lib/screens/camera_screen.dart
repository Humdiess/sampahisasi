import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/tflite_service.dart';
import '../widgets/result_overlay.dart';
import '../widgets/scanner_overlay.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  final TfliteService _tfliteService = TfliteService();
  bool _isDetecting = false;
  List<double>? _currentPrediction; // [organic, anorganic]
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _tfliteService.loadModel();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) return;

    // Use rear camera by default
    final camera = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.medium, // Medium usually sufficient for ML
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;

      setState(() {});

      _controller!.startImageStream((image) {
        _FRAME_RATE_LIMITER(image);
      });
    } catch (e) {
      print('Camera error: $e');
    }
  }

  void _FRAME_RATE_LIMITER(CameraImage image) {
    if (_isDetecting) return;
    _frameCount++;
    if (_frameCount % 3 != 0) return; // Process every 3rd frame to reduce load

    _isDetecting = true;
    _log('Processing frame $_frameCount'); // Debug log

    _tfliteService
        .classifyImage(image)
        .then((prediction) {
          _log('Prediction: $prediction'); // Debug log
          if (mounted && prediction != null) {
            setState(() {
              _currentPrediction = prediction;
            });
          } else {
            _log('Prediction was null');
          }
          _isDetecting = false;
        })
        .catchError((e) {
          _log('Error detecting: $e'); // Debug log
          _isDetecting = false;
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _tfliteService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  final List<String> _logs = []; // Debug logs

  void _log(String message) {
    if (!mounted) return;
    setState(() {
      _logs.add(
        "${DateTime.now().second}:${DateTime.now().millisecond} - $message",
      );
      if (_logs.length > 10) _logs.removeAt(0);
    });
    print(message);
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),

          // Scanner UI (Always Visible)
          const ScannerOverlay(),

          // Instruction Text (Top)
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Arahkan kamera ke sampah",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          // Result Overlay (Bottom)
          if (_currentPrediction != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: ResultOverlay(
                prediction: _currentPrediction!,
                labels: _tfliteService.labels ?? ['Organik', 'Anorganik'],
              ),
            ),

          // Debug Log Overlay (Small, bottom right or temporary)
          if (_logs.isNotEmpty) // Only show if logs exist
            Align(
              alignment: Alignment.topRight,
              child: Container(
                margin: const EdgeInsets.only(top: 100, right: 10),
                padding: const EdgeInsets.all(4),
                color: Colors.black45,
                width: 200,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "DEBUG:",
                      style: TextStyle(color: Colors.red, fontSize: 10),
                    ),
                    ..._logs.map(
                      (e) => Text(
                        e,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
