import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class ImageUtils {
  /// Converts a [CameraImage] in YUV420 format to [img.Image] in RGB format
  static img.Image? convertYUV420ToImage(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;

    final yRowStride = cameraImage.planes[0].bytesPerRow;
    final uvRowStride = cameraImage.planes[1].bytesPerRow;
    final uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;

    final image = img.Image(width: width, height: height);

    for (var w = 0; w < width; w++) {
      for (var h = 0; h < height; h++) {
        final uvIndex =
            uvPixelStride * (w / 2).floor() + uvRowStride * (h / 2).floor();

        final yIndex = h * yRowStride + w;

        final y = cameraImage.planes[0].bytes[yIndex];
        final u = cameraImage.planes[1].bytes[uvIndex];
        final v = cameraImage.planes[2].bytes[uvIndex];

        image.data!.setPixelRgb(
          w,
          h,
          y + (1.370705 * (v - 128)).toInt(),
          y - (0.337633 * (u - 128)) - (0.698001 * (v - 128)).toInt(),
          y + (1.732446 * (u - 128)).toInt(),
        );
      }
    }
    return image;
  }
}
