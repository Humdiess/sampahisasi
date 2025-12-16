import 'package:flutter/material.dart';

class ScannerOverlay extends StatefulWidget {
  const ScannerOverlay({super.key});

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: ScannerPainter(_controller.value),
          child: Container(),
        );
      },
    );
  }
}

class ScannerPainter extends CustomPainter {
  final double scanValue;

  ScannerPainter(this.scanValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final width = size.width;
    final height = size.height;
    final scanAreaSize = width * 0.7; // 70% of screen width
    final left = (width - scanAreaSize) / 2;
    final top = (height - scanAreaSize) / 2;
    final right = left + scanAreaSize;
    final bottom = top + scanAreaSize;

    // Draw Corners
    final cornerLength = 30.0;

    // Top Left
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left, top + cornerLength), paint);

    // Top Right
    canvas.drawLine(
      Offset(right, top),
      Offset(right - cornerLength, top),
      paint,
    );
    canvas.drawLine(
      Offset(right, top),
      Offset(right, top + cornerLength),
      paint,
    );

    // Bottom Left
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left + cornerLength, bottom),
      paint,
    );
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left, bottom - cornerLength),
      paint,
    );

    // Bottom Right
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right - cornerLength, bottom),
      paint,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right, bottom - cornerLength),
      paint,
    );

    // Scan Line
    final lineY = top + (scanAreaSize * scanValue);
    final linePaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.8)
      ..strokeWidth = 2.0
      ..shader = LinearGradient(
        colors: [
          Colors.greenAccent.withOpacity(0.0),
          Colors.greenAccent,
          Colors.greenAccent.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(left, lineY, scanAreaSize, 2));

    canvas.drawLine(
      Offset(left + 10, lineY),
      Offset(right - 10, lineY),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(ScannerPainter oldDelegate) => true;
}
