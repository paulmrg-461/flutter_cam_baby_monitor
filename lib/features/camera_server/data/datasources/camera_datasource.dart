import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import '../../domain/entities/stream_config.dart';

class CameraDatasource {
  CameraController? _controller;
  StreamController<Uint8List>? _frameController;
  CameraImage? _lastImage;
  Timer? _throttleTimer;
  bool _isStreaming = false;
  late StreamConfig _config;

  CameraController? get controller => _controller;
  bool get isStreaming => _isStreaming;

  Future<void> initialize(StreamConfig config) async {
    _config = config;

    final cameras = await availableCameras();
    final selectedCamera = cameras.firstWhere(
      (c) => c.lensDirection == config.lensDirection,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      selectedCamera,
      config.resolution,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await _controller!.initialize();
  }

  Stream<Uint8List> startImageStream() {
    _isStreaming = true;
    _frameController = StreamController<Uint8List>();

    _controller!.startImageStream((CameraImage image) {
      _lastImage = image;
    });

    final frameInterval = Duration(
      milliseconds: max(1, (1000 / _config.targetFps).round()),
    );
    _throttleTimer = Timer.periodic(frameInterval, (_) {
      if (_lastImage != null &&
          _frameController != null &&
          !_frameController!.isClosed) {
        final jpeg = _convertToJpeg(_lastImage!);
        if (jpeg != null) {
          _frameController!.add(jpeg);
        }
      }
    });

    return _frameController!.stream;
  }

  void stopImageStream() {
    _isStreaming = false;
    _throttleTimer?.cancel();
    _throttleTimer = null;
    _controller?.stopImageStream();
    _frameController?.close();
    _frameController = null;
    _lastImage = null;
  }

  Uint8List? _convertToJpeg(CameraImage image) {
    try {
      final width = image.width;
      final height = image.height;

      final imgImage = img.Image(width: width, height: height);

      final format = image.format;
      if (format == ImageFormatGroup.nv21) {
        _nv21ToImage(image, imgImage, width, height);
      } else if (format == ImageFormatGroup.yuv420) {
        _yuv420ToImage(image, imgImage, width, height);
      } else if (format == ImageFormatGroup.bgra8888) {
        _bgraToImage(image, imgImage, width, height);
      } else {
        return null;
      }

      final jpeg = img.encodeJpg(imgImage, quality: _config.quality);
      return Uint8List.fromList(jpeg);
    } catch (_) {
      return null;
    }
  }

  void _nv21ToImage(CameraImage image, img.Image imgImage, int width, int height) {
    final yPlane = image.planes[0];
    final vuPlane = image.planes[1];

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final yValue = yPlane.bytes[y * yPlane.bytesPerRow + x];

        final vuIndex = (y ~/ 2) * vuPlane.bytesPerRow + (x ~/ 2) * 2;
        final vValue = vuPlane.bytes[vuIndex];
        final uValue = vuPlane.bytes[vuIndex + 1];

        final r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
        final g = (yValue - 0.344 * (uValue - 128) - 0.714 * (vValue - 128)).round().clamp(0, 255);
        final b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);

        imgImage.setPixelRgba(x, y, r, g, b, 255);
      }
    }
  }

  void _yuv420ToImage(CameraImage image, img.Image imgImage, int width, int height) {
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final yValue = yPlane.bytes[y * yPlane.bytesPerRow + x];

        final uvIndex = (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2);
        final uValue = uPlane.bytes[uvIndex];
        final vValue = vPlane.bytes[uvIndex];

        final r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
        final g = (yValue - 0.344 * (uValue - 128) - 0.714 * (vValue - 128)).round().clamp(0, 255);
        final b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);

        imgImage.setPixelRgba(x, y, r, g, b, 255);
      }
    }
  }

  void _bgraToImage(CameraImage image, img.Image imgImage, int width, int height) {
    final plane = image.planes[0];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final offset = y * plane.bytesPerRow + x * 4;
        final b = plane.bytes[offset];
        final g = plane.bytes[offset + 1];
        final r = plane.bytes[offset + 2];
        final a = plane.bytes[offset + 3];
        imgImage.setPixelRgba(x, y, r, g, b, a);
      }
    }
  }

  Future<void> dispose() async {
    stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }
}
