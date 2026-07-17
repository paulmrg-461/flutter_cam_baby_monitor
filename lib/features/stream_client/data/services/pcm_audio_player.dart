
import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

import 'audio_jitter_buffer.dart';

/// Thin adapter wiring [AudioJitterBuffer] to the native PCM playback
/// engine. FlutterPcmSound pulls samples via a feed callback whenever its
/// internal buffer runs low; this answers that pull from the jitter buffer
/// instead of the raw network stream, so playback stays smooth even when
/// chunks arrive unevenly over wifi.
class PcmAudioPlayer {
  PcmAudioPlayer({AudioJitterBuffer? buffer}) : _buffer = buffer ?? AudioJitterBuffer();

  static const _sampleRate = 16000;
  static const _feedChunkMs = 100;
  static const _bytesPerFeed = _sampleRate * _feedChunkMs ~/ 1000 * 2;

  final AudioJitterBuffer _buffer;
  bool _isSetup = false;
  bool _loggedFirstFeed = false;

  Future<void> start() async {
    if (_isSetup) return;
    await FlutterPcmSound.setup(sampleRate: _sampleRate, channelCount: 1);
    FlutterPcmSound.setFeedCallback(_onFeed);
    _isSetup = true;
    debugPrint('[PcmAudioPlayer] setup done, sampleRate=$_sampleRate');
  }

  void feed(Uint8List chunk) {
    _buffer.push(chunk);
    if (_buffer.isPrimed) {
      if (!_loggedFirstFeed) {
        _loggedFirstFeed = true;
        debugPrint('[PcmAudioPlayer] buffer primed (${_buffer.bufferedBytes} bytes), starting playback');
      }
      FlutterPcmSound.start();
    }
  }

  void _onFeed(int remainingFrames) {
    final chunk = _buffer.pull(_bytesPerFeed);
    if (chunk == null) return;
    FlutterPcmSound.feed(
      PcmArrayInt16(
        bytes: chunk.buffer.asByteData(chunk.offsetInBytes, chunk.lengthInBytes),
      ),
    );
  }

  Future<void> stop() async {
    _buffer.reset();
    _loggedFirstFeed = false;
    if (!_isSetup) return;
    _isSetup = false;
    FlutterPcmSound.setFeedCallback(null);
    await FlutterPcmSound.release();
  }
}
