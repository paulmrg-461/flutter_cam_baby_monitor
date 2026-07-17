import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';

import '../../domain/entities/stream_config.dart';
import '../../domain/repositories/camera_repository.dart';
import '../datasources/camera_datasource.dart';
import '../datasources/mjpeg_server.dart';

class CameraRepositoryImpl implements CameraRepository {
  CameraRepositoryImpl({
    required this._cameraDatasource,
    required this._mjpegServer,
  });

  final CameraDatasource _cameraDatasource;
  final MjpegServer _mjpegServer;
  StreamSubscription<Uint8List>? _frameSubscription;
  late StreamConfig _config;

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
  }

  @override
  Future<void> stopStreaming() async {
    _cameraDatasource.stopImageStream();
  }

  @override
  Future<void> dispose() async {
    _frameSubscription?.cancel();
    await _cameraDatasource.dispose();
    await _mjpegServer.stop();
  }
}
