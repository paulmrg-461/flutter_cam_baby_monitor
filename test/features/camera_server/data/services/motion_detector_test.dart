import 'dart:typed_data';

import 'package:baby_monitor/features/camera_server/data/services/motion_detector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _solidJpeg({int width = 96, int height = 72, required img.Color color}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: color);
  return img.encodeJpg(image);
}

Uint8List _framesWithBlock({int width = 96, int height = 72}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(20, 20, 20));
  img.fillRect(
    image,
    x1: 0,
    y1: 0,
    x2: width - 1,
    y2: height - 1,
    color: img.ColorRgb8(230, 230, 230),
  );
  return img.encodeJpg(image);
}

void main() {
  group('MotionDetector', () {
    test('success: a large brightness change across the frame triggers motion', () {
      final detector = MotionDetector(cooldown: Duration.zero);
      final dark = _solidJpeg(color: img.ColorRgb8(20, 20, 20));
      final bright = _framesWithBlock();

      expect(detector.feed(dark), isFalse); // first frame: no baseline yet
      expect(detector.feed(bright), isTrue);
    });

    test('failure: identical consecutive frames never trigger motion', () {
      final detector = MotionDetector(cooldown: Duration.zero);
      final frame = _solidJpeg(color: img.ColorRgb8(100, 100, 100));

      expect(detector.feed(frame), isFalse);
      expect(detector.feed(frame), isFalse);
      expect(detector.feed(frame), isFalse);
    });

    test(
      'security: malformed/non-JPEG bytes never throw and never trigger a false alert',
      () {
        final detector = MotionDetector(cooldown: Duration.zero);
        final garbage = Uint8List.fromList(List<int>.generate(64, (i) => i));

        expect(() => detector.feed(garbage), returnsNormally);
        expect(detector.feed(garbage), isFalse);
        expect(detector.feed(Uint8List(0)), isFalse);
      },
    );

    test('cooldown suppresses repeated triggers within the window', () {
      final detector = MotionDetector(cooldown: const Duration(minutes: 5));
      final dark = _solidJpeg(color: img.ColorRgb8(20, 20, 20));
      final bright = _framesWithBlock();

      detector.feed(dark);
      expect(detector.feed(bright), isTrue);
      // Same abrupt change again immediately after: still inside cooldown.
      expect(detector.feed(dark), isFalse);
    });

    test('reset() drops the baseline so the next frame cannot trigger a comparison', () {
      final detector = MotionDetector(cooldown: Duration.zero);
      final dark = _solidJpeg(color: img.ColorRgb8(20, 20, 20));
      final bright = _framesWithBlock();

      detector.feed(dark);
      detector.reset();
      expect(detector.feed(bright), isFalse); // no baseline right after reset
    });
  });
}
