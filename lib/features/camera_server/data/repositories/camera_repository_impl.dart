import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/stream_config.dart';
import '../../domain/repositories/camera_repository.dart';
import '../datasources/audio_datasource.dart';
import '../datasources/camera_datasource.dart';
import '../datasources/mjpeg_server.dart';
import '../datasources/native_camera_datasource.dart';

class CameraRepositoryImpl implements CameraRepository {
  CameraRepositoryImpl({
    required this._cameraDatasource,
    required this._mjpegServer,
    required this._nativeCameraDatasource,
    required this._audioDatasource,
  });

  final CameraDatasource _cameraDatasource;
  final MjpegServer _mjpegServer;
  final NativeCameraDatasource _nativeCameraDatasource;
  final AudioDatasource _audioDatasource;
  StreamSubscription<Uint8List>? _frameSubscription;
  late StreamConfig _config;
  bool _isBackgroundCapture = false;

  @override
  StreamConfig get config => _config;

  @override
  CameraController? get cameraController => _cameraDatasource.controller;

  @override
  Stream<Uint8List> get frameStream => _mjpegServer.frameStream;

  @override
  Future<void> initialize(StreamConfig config) async {
    _config = config;
    await _cameraDatasource.initialize(config);
    await _mjpegServer.start(port: config.port, authToken: config.authToken);
  }

  @override
  Future<void> startStreaming() async {
    final imageStream = _cameraDatasource.startImageStream();
    _mjpegServer.bindFrameStream(imageStream);

    // Audio is a best-effort enhancement: a denied mic permission must
    // never block video streaming, so this never throws.
    final audioStream = await _audioDatasource.start();
    debugPrint('[CameraRepositoryImpl] audioStream acquired: ${audioStream != null}');
    if (audioStream != null) {
      _mjpegServer.bindAudioStream(audioStream);
    }

    // Must start while the app is visible: Android 14+ requires a
    // camera/microphone-typed foreground service to be launched from the
    // foreground, with the underlying permissions already granted.
    await _nativeCameraDatasource.startService(micEnabled: audioStream != null);
  }

  @override
  Future<void> stopStreaming() async {
    if (_isBackgroundCapture) {
      _isBackgroundCapture = false;
    }
    await _audioDatasource.stop();
    await _nativeCameraDatasource.stopService();
    _cameraDatasource.stopImageStream();
  }

  @override
  Future<void> handleAppBackgrounded() async {
    if (!_cameraDatasource.isStreaming || _isBackgroundCapture) return;
    _isBackgroundCapture = true;

    final (width, height) = _pixelSizeFor(_config.resolution);
    await _cameraDatasource.dispose();
    await _nativeCameraDatasource.acquireCamera(
      lensDirection: _config.lensDirection,
      width: width,
      height: height,
      quality: _config.quality,
      targetFps: _config.targetFps,
    );
    _mjpegServer.bindFrameStream(_nativeCameraDatasource.frameStream);
  }

  @override
  Future<void> handleAppForegrounded() async {
    if (!_isBackgroundCapture) return;
    _isBackgroundCapture = false;

    await _nativeCameraDatasource.releaseCamera();
    await _cameraDatasource.initialize(_config);
    final imageStream = _cameraDatasource.startImageStream();
    _mjpegServer.bindFrameStream(imageStream);
  }

  (int, int) _pixelSizeFor(ResolutionPreset preset) {
    switch (preset) {
      case ResolutionPreset.low:
        return (320, 240);
      case ResolutionPreset.medium:
        return (720, 480);
      case ResolutionPreset.high:
        return (1280, 720);
      case ResolutionPreset.veryHigh:
        return (1920, 1080);
      case ResolutionPreset.ultraHigh:
      case ResolutionPreset.max:
        return (3840, 2160);
    }
  }

  @override
  Future<void> dispose() async {
    _frameSubscription?.cancel();
    _isBackgroundCapture = false;
    await _audioDatasource.dispose();
    await _nativeCameraDatasource.stopService();
    await _cameraDatasource.dispose();
    await _mjpegServer.stop();
  }
}
