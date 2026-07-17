import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../domain/entities/stream_config.dart';

class CameraDatasource {
  CameraController? _controller;
  StreamController<Uint8List>? _frameController;
  CameraImage? _lastImage;
  Timer? _throttleTimer;
  bool _isStreaming = false;
  bool _isConverting = false;
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
    _throttleTimer = Timer.periodic(frameInterval, (_) => _emitNextFrame());

    return _frameController!.stream;
  }

  void _emitNextFrame() {
    if (_isConverting || _lastImage == null) return;
    if (_frameController == null || _frameController!.isClosed) return;

    _isConverting = true;
    final frameData = _buildFrameData(_lastImage!);

    compute(convertFrameToJpeg, frameData).then((jpeg) {
      _isConverting = false;
      if (jpeg != null &&
          _frameController != null &&
          !_frameController!.isClosed) {
        _frameController!.add(jpeg);
      }
    }).catchError((_) {
      _isConverting = false;
    });
  }

  FrameConversionData _buildFrameData(CameraImage image) {
    return FrameConversionData(
      width: image.width,
      height: image.height,
      format: image.format.group,
      quality: _config.quality,
      planeBytes: [
        for (final plane in image.planes) Uint8List.fromList(plane.bytes),
      ],
      bytesPerRow: [for (final plane in image.planes) plane.bytesPerRow],
    );
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

  Future<void> dispose() async {
    stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }
}

@immutable
class FrameConversionData {
  final int width;
  final int height;
  final ImageFormatGroup format;
  final int quality;
  final List<Uint8List> planeBytes;
  final List<int> bytesPerRow;

  const FrameConversionData({
    required this.width,
    required this.height,
    required this.format,
    required this.quality,
    required this.planeBytes,
    required this.bytesPerRow,
  });
}

/// Runs on a background isolate via [compute]; must stay a top-level function.
Uint8List? convertFrameToJpeg(FrameConversionData data) {
  try {
    final imgImage = img.Image(width: data.width, height: data.height);

    switch (data.format) {
      case ImageFormatGroup.nv21:
        _nv21ToImage(data, imgImage);
      case ImageFormatGroup.yuv420:
        _yuv420ToImage(data, imgImage);
      case ImageFormatGroup.bgra8888:
        _bgraToImage(data, imgImage);
      default:
        return null;
    }

    return Uint8List.fromList(img.encodeJpg(imgImage, quality: data.quality));
  } catch (_) {
    return null;
  }
}

void _nv21ToImage(FrameConversionData data, img.Image imgImage) {
  final yBytes = data.planeBytes[0];
  final yStride = data.bytesPerRow[0];

  // Some camera implementations deliver NV21 as a single packed plane
  // (Y rows followed immediately by interleaved VU rows) instead of two
  // separate Plane objects. Detect and handle both layouts.
  final hasSeparateVuPlane = data.planeBytes.length > 1;
  final vuBytes = hasSeparateVuPlane ? data.planeBytes[1] : yBytes;
  final vuStride = hasSeparateVuPlane ? data.bytesPerRow[1] : yStride;
  final vuOffset = hasSeparateVuPlane ? 0 : yStride * data.height;

  for (var y = 0; y < data.height; y++) {
    for (var x = 0; x < data.width; x++) {
      final yValue = yBytes[y * yStride + x];

      final vuIndex = vuOffset + (y ~/ 2) * vuStride + (x ~/ 2) * 2;
      final vValue = vuBytes[vuIndex];
      final uValue = vuBytes[vuIndex + 1];

      _setYuvPixel(imgImage, x, y, yValue, uValue, vValue);
    }
  }
}

void _yuv420ToImage(FrameConversionData data, img.Image imgImage) {
  final yBytes = data.planeBytes[0];
  final yStride = data.bytesPerRow[0];
  final uBytes = data.planeBytes[1];
  final vBytes = data.planeBytes[2];
  final uvStride = data.bytesPerRow[1];

  for (var y = 0; y < data.height; y++) {
    for (var x = 0; x < data.width; x++) {
      final yValue = yBytes[y * yStride + x];

      final uvIndex = (y ~/ 2) * uvStride + (x ~/ 2);
      final uValue = uBytes[uvIndex];
      final vValue = vBytes[uvIndex];

      _setYuvPixel(imgImage, x, y, yValue, uValue, vValue);
    }
  }
}

void _setYuvPixel(
  img.Image imgImage,
  int x,
  int y,
  int yValue,
  int uValue,
  int vValue,
) {
  final r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
  final g = (yValue - 0.344 * (uValue - 128) - 0.714 * (vValue - 128))
      .round()
      .clamp(0, 255);
  final b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);

  imgImage.setPixelRgba(x, y, r, g, b, 255);
}

void _bgraToImage(FrameConversionData data, img.Image imgImage) {
  final plane = data.planeBytes[0];
  final stride = data.bytesPerRow[0];

  for (var y = 0; y < data.height; y++) {
    for (var x = 0; x < data.width; x++) {
      final offset = y * stride + x * 4;
      final b = plane[offset];
      final g = plane[offset + 1];
      final r = plane[offset + 2];
      final a = plane[offset + 3];
      imgImage.setPixelRgba(x, y, r, g, b, a);
    }
  }
}
