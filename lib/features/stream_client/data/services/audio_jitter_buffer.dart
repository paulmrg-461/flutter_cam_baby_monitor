import 'dart:collection';
import 'dart:typed_data';

/// Smooths out network jitter for the live audio feed: holds playback back
/// until enough audio has buffered, then drains steadily. Robustness over
/// latency — for a baby monitor a ~1s delay is invisible, a stutter isn't.
class AudioJitterBuffer {
  AudioJitterBuffer({
    this.sampleRate = 16000,
    this.bytesPerSample = 2,
    this.channels = 1,
    Duration prefill = const Duration(milliseconds: 1200),
  }) : _prefillBytes = _msToBytes(prefill.inMilliseconds, sampleRate, bytesPerSample, channels);

  final int sampleRate;
  final int bytesPerSample;
  final int channels;
  final int _prefillBytes;

  final _queue = Queue<int>();
  bool _primed = false;

  /// True once enough audio has buffered to start draining playback.
  bool get isPrimed => _primed;
  int get bufferedBytes => _queue.length;

  void push(Uint8List chunk) {
    _queue.addAll(chunk);
    if (!_primed && _queue.length >= _prefillBytes) {
      _primed = true;
    }
  }

  /// Pulls up to [maxBytes] of playback-ready audio, or null if not primed
  /// yet or nothing is buffered. Always returns an even byte count — a
  /// 16-bit sample must never be split across pulls.
  Uint8List? pull(int maxBytes) {
    if (!_primed || _queue.isEmpty) return null;

    final evenMax = maxBytes - (maxBytes % 2);
    final available = _queue.length - (_queue.length % 2);
    final count = available < evenMax ? available : evenMax;
    if (count <= 0) return null;

    final out = Uint8List(count);
    for (var i = 0; i < count; i++) {
      out[i] = _queue.removeFirst();
    }
    // Underrun: re-buffer up to the prefill threshold before resuming,
    // rather than draining in tiny, choppy increments.
    if (_queue.isEmpty) _primed = false;
    return out;
  }

  void reset() {
    _queue.clear();
    _primed = false;
  }

  static int _msToBytes(int ms, int sampleRate, int bytesPerSample, int channels) {
    final samples = (sampleRate * ms / 1000).round();
    return samples * bytesPerSample * channels;
  }
}
