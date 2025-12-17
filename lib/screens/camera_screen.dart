import 'dart:io';
import 'dart:ui'; // Import for ImageFilter
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'chat_screen.dart'; // Import ChatScreen
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

  // New State Variables
  File? _pickedImage;
  FlashMode _flashMode = FlashMode.off;
  CameraLensDirection _currentLensDirection = CameraLensDirection.back;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.cameras.isNotEmpty) {
      _initializeCamera(
        widget.cameras.firstWhere(
          (c) => c.lensDirection == _currentLensDirection,
          orElse: () => widget.cameras.first,
        ),
      );
    }
    _tfliteService.loadModel();
  }

  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    final previousController = _controller;

    // 1. Fix Red Screen: clear controller immediately so UI shows loading
    if (mounted) {
      setState(() {
        _controller = null;
      });
    }

    // Dispose previous controller
    if (previousController != null) {
      await previousController.dispose();
    }

    // Initialize new controller
    final controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium, // Keeping Medium for quality
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await controller.initialize();
      // Set initial flash mode (only if supported/back camera)
      if (cameraDescription.lensDirection == CameraLensDirection.back &&
          controller.value.flashMode != _flashMode) {
        await controller.setFlashMode(_flashMode);
      }

      if (!mounted) return;

      setState(() {
        _controller = controller;
      });

      controller.startImageStream((image) {
        _FRAME_RATE_LIMITER(image);
      });
    } catch (e) {
      print('Camera error: $e');
    }
  }

  void _FRAME_RATE_LIMITER(CameraImage image) {
    if (_pickedImage != null) return;
    if (_isDetecting) return;
    _frameCount++;
    // 2. Optimization: Throttle to ~1 detection per second (30fps / 30 = 1fps)
    if (_frameCount % 30 != 0) return;

    _isDetecting = true;

    _tfliteService
        .classifyImage(image)
        .then((prediction) {
          if (mounted && prediction != null) {
            setState(() {
              _currentPrediction = prediction;
            });
          }
          _isDetecting = false;
        })
        .catchError((e) {
          _isDetecting = false;
        });
  }

  // Toggle Flash
  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_currentLensDirection == CameraLensDirection.front)
      return; // Disable for front

    FlashMode newMode;
    if (_flashMode == FlashMode.off) {
      newMode = FlashMode.torch;
    } else {
      newMode = FlashMode.off;
    }

    try {
      await _controller!.setFlashMode(newMode);
      setState(() {
        _flashMode = newMode;
      });
    } catch (e) {
      print('Error toggling flash: $e');
    }
  }

  // Switch Camera
  Future<void> _switchCamera() async {
    if (widget.cameras.length < 2) return;

    final newDirection = _currentLensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    final newCamera = widget.cameras.firstWhere(
      (c) => c.lensDirection == newDirection,
      orElse: () => widget.cameras.first,
    );

    setState(() {
      _currentLensDirection = newDirection;
      _currentPrediction = null;
      // Reset flash when switching to front
      if (newDirection == CameraLensDirection.front) {
        _flashMode = FlashMode.off;
      }
    });

    await _initializeCamera(newCamera);
  }

  // Pick Image from Gallery
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      // Stop camera stream temporarily essentially by just setting state
      // (Actually stream continues in background but specific FRAME_RATE_LIMITER logic skips it)
      // or we can pause controller? For now simpler to just ignore stream updates.

      setState(() {
        _pickedImage = File(pickedFile.path);
        _currentPrediction = null; // Reset until classified
        _isDetecting = true; // Show loading if needed
      });

      final prediction = await _tfliteService.classifyFile(_pickedImage!);
      if (mounted) {
        setState(() {
          _currentPrediction = prediction;
          _isDetecting = false;
        });
      }
    }
  }

  // Close static image and return to camera
  void _clearPickedImage() {
    setState(() {
      _pickedImage = null;
      _currentPrediction = null;
    });
  }

  void _openChat() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ChatScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0); // Start from bottom
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
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

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // Re-initialize with current direction
      if (widget.cameras.isNotEmpty) {
        _initializeCamera(
          widget.cameras.firstWhere(
            (c) => c.lensDirection == _currentLensDirection,
            orElse: () => widget.cameras.first,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Static Image Mode
    if (_pickedImage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _clearPickedImage,
          ),
        ),
        extendBodyBehindAppBar: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(_pickedImage!, fit: BoxFit.cover),
            if (_currentPrediction != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: ResultOverlay(
                  prediction: _currentPrediction!,
                  labels: _tfliteService.labels ?? ['Organik', 'Anorganik'],
                ),
              ),
            if (_isDetecting)
              const Center(
                child: CircularProgressIndicator(color: Colors.green),
              ),
          ],
        ),
      );
    }

    // 2. Camera Mode
    // Show black background with loader if initializing (prevents Red Screen)
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    final isFrontCamera = _currentLensDirection == CameraLensDirection.front;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated Camera Preview Switch
          // We use a SizedBox.expand to ensure it fills space
          SizedBox.expand(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: _controller != null && _controller!.value.isInitialized
                  ? Transform.scale(
                      key: ValueKey(
                        _currentLensDirection,
                      ), // Key triggers animation on change
                      scale:
                          1 /
                          (_controller!.value.aspectRatio *
                              MediaQuery.of(context).size.aspectRatio),
                      child: Center(child: CameraPreview(_controller!)),
                    )
                  : Container(
                      // Placeholder during switch
                      key: const ValueKey("loader"),
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.green),
                      ),
                    ),
            ),
          ),

          // Scanner Overlay
          const ScannerOverlay(),

          // GLASS TOP BAR
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left: Flash & Chat
                      Row(
                        children: [
                          _buildGlassIconButton(
                            icon: _flashMode == FlashMode.torch
                                ? Icons.flash_on
                                : Icons.flash_off,
                            color: isFrontCamera
                                ? Colors.white38
                                : (_flashMode == FlashMode.torch
                                      ? Colors.yellow
                                      : Colors.white),
                            onPressed: isFrontCamera ? null : _toggleFlash,
                          ),
                          const SizedBox(width: 8),
                          _buildGlassIconButton(
                            icon: Icons.chat_bubble_outline,
                            onPressed: _openChat,
                          ),
                        ],
                      ),

                      // Center: Title
                      const Text(
                        "Sampahisasi",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),

                      // Right: Gallery & Switch
                      Row(
                        children: [
                          _buildGlassIconButton(
                            icon: Icons.image,
                            onPressed: _pickImage,
                          ),
                          const SizedBox(width: 8),
                          _buildGlassIconButton(
                            icon: Icons.cameraswitch_rounded,
                            onPressed: _switchCamera,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // CONDITIONAL INSTRUCTION (Glassmorphism)
          if (_currentPrediction == null)
            Positioned(
              top: 140, // Below Top Bar
              left: 0,
              right: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: const Text(
                        "Arahkan kamera ke sampah",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Result Overlay (Placed BEFORE floating button in Stack? No, we want Button ON TOP)
          if (_currentPrediction != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: ResultOverlay(
                prediction: _currentPrediction!,
                labels: _tfliteService.labels ?? ['Organik', 'Anorganik'],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    Color color = Colors.white,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(
          0.2,
        ), // Subtle dark background for contrast inside light glass bar
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}
