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

  /// Hands frame capture off to a native background camera session so
  /// streaming survives the screen turning off. No-op if not streaming.
  Future<void> handleAppBackgrounded();

  /// Hands frame capture back to the normal foreground camera pipeline.
  /// No-op if capture isn't currently running in the background.
  Future<void> handleAppForegrounded();

  Future<void> dispose();
}
