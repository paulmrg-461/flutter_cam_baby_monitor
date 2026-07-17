import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Captures raw PCM16 audio from the microphone via `record`. Unlike the
/// camera (CameraX is bound to the Activity lifecycle), `record`'s Android
/// implementation only needs the application context, so capture keeps
/// running through the app backgrounding/foregrounding handoff without any
/// native rewrite.
class AudioDatasource {
  AudioDatasource({AudioRecorder? recorder}) : _recorder = recorder ?? AudioRecorder();

  static const sampleRate = 16000;
  static const numChannels = 1;

  final AudioRecorder _recorder;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Checks (and, if needed, requests) the RECORD_AUDIO permission.
  /// Callers must resolve this before promoting a microphone-typed
  /// foreground service — Android 14+ requires the permission already
  /// granted at that point.
  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Starts capturing. Returns null instead of throwing if the microphone
  /// permission isn't granted — audio is an optional enhancement and must
  /// never block the underlying video stream.
  Future<Stream<Uint8List>?> start() async {
    final granted = await hasPermission();
    debugPrint('[AudioDatasource] hasPermission -> $granted');
    if (!granted) return null;

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: numChannels,
      ),
    );
    _isRecording = true;
    debugPrint('[AudioDatasource] startStream ok, isRecording=$_isRecording');
    var loggedFirstChunk = false;
    return stream.map((chunk) {
      if (!loggedFirstChunk) {
        loggedFirstChunk = true;
        debugPrint('[AudioDatasource] first captured chunk: ${chunk.length} bytes');
      }
      return chunk;
    });
  }

  Future<void> stop() async {
    if (!_isRecording) return;
    _isRecording = false;
    await _recorder.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
  }
}
