import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Cheap frame-differencing motion detector: downsamples each JPEG frame to
/// a small grayscale grid and compares it against the previous one. No ML
/// model, runs inline in the frame pipeline.
class MotionDetector {
  MotionDetector({
    this.sensitivity = 0.06,
    this.cooldown = const Duration(seconds: 10),
    this.sampleWidth = 48,
    this.sampleHeight = 36,
    this.pixelThreshold = 25,
  });

  /// Fraction (0.0-1.0) of sampled pixels that must change to trigger.
  final double sensitivity;

  /// Minimum gap between consecutive triggers, to avoid alert spam.
  final Duration cooldown;

  final int sampleWidth;
  final int sampleHeight;

  /// Minimum per-pixel luminance delta to count a pixel as "changed".
  final int pixelThreshold;

  Uint8List? _previousLuma;
  DateTime? _lastTriggered;

  /// Feeds a JPEG frame in. Returns true if this frame should raise a
  /// motion alert (threshold crossed and outside the cooldown window).
  bool feed(Uint8List jpegBytes) {
    img.Image? decoded;
    try {
      decoded = img.decodeJpg(jpegBytes);
    } catch (_) {
      // Corrupt/truncated frame (e.g. dropped mid-transfer): skip this
      // frame instead of taking down the capture pipeline.
      return false;
    }
    if (decoded == null) return false;

    final luma = _toLumaGrid(decoded);
    final prev = _previousLuma;
    _previousLuma = luma;
    if (prev == null || prev.length != luma.length) return false;

    var changed = 0;
    for (var i = 0; i < luma.length; i++) {
      if ((luma[i] - prev[i]).abs() > pixelThreshold) changed++;
    }

    if (changed / luma.length < sensitivity) return false;
    return _tryTrigger();
  }

  Uint8List _toLumaGrid(img.Image decoded) {
    final small = img.copyResize(
      decoded,
      width: sampleWidth,
      height: sampleHeight,
      interpolation: img.Interpolation.nearest,
    );

    final luma = Uint8List(sampleWidth * sampleHeight);
    var i = 0;
    for (final pixel in small) {
      luma[i++] = pixel.luminance.round().clamp(0, 255);
    }
    return luma;
  }

  bool _tryTrigger() {
    final now = DateTime.now();
    final last = _lastTriggered;
    if (last != null && now.difference(last) < cooldown) return false;
    _lastTriggered = now;
    return true;
  }

  /// Drops the reference frame — call when the capture source changes
  /// (e.g. CameraX <-> native Camera2 handoff) so a stale comparison
  /// against a frame from the other pipeline can't fire a false trigger.
  void reset() {
    _previousLuma = null;
    _lastTriggered = null;
  }
}
