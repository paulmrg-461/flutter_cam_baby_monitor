import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';

import '../../domain/entities/stream_config.dart';

abstract class CameraRepository {
  Future<void> initialize(StreamConfig config);
  Future<void> startStreaming();
  Future<void> stopStreaming();
  Stream<Uint8List> get frameStream;
  CameraController? get cameraController;
  StreamConfig get config;
  Future<void> dispose();
}
