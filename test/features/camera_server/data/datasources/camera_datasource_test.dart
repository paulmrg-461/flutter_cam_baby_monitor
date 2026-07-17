import 'dart:typed_data';

import 'package:baby_monitor/features/camera_server/data/datasources/camera_datasource.dart';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _yPlane(int width, int height, int value) =>
    Uint8List.fromList(List.filled(width * height, value));

Uint8List _vuBytes(int width, int height, int vValue, int uValue) {
  final bytes = <int>[];
  for (var r = 0; r < height ~/ 2; r++) {
    for (var c = 0; c < width ~/ 2; c++) {
      bytes
        ..add(vValue)
        ..add(uValue);
    }
  }
  return Uint8List.fromList(bytes);
}

void main() {
  const width = 8;
  const height = 8;

  test(
    'success: converts NV21 delivered as a single packed plane (Y + interleaved VU) into a valid JPEG',
    () {
      final packed = Uint8List.fromList([
        ..._yPlane(width, height, 180),
        ..._vuBytes(width, height, 140, 120),
      ]);

      final data = FrameConversionData(
        width: width,
        height: height,
        format: ImageFormatGroup.nv21,
        quality: 80,
        planeBytes: [packed],
        bytesPerRow: [width],
      );

      final jpeg = convertFrameToJpeg(data);

      expect(jpeg, isNotNull);
      expect(img.decodeJpg(jpeg!), isNotNull);
    },
  );

  test(
    'success: converts NV21 delivered as two separate planes (Y, interleaved VU) into a valid JPEG',
    () {
      final data = FrameConversionData(
        width: width,
        height: height,
        format: ImageFormatGroup.nv21,
        quality: 80,
        planeBytes: [
          _yPlane(width, height, 180),
          _vuBytes(width, height, 140, 120),
        ],
        bytesPerRow: [width, width],
      );

      final jpeg = convertFrameToJpeg(data);

      expect(jpeg, isNotNull);
      expect(img.decodeJpg(jpeg!), isNotNull);
    },
  );

  test('failure: an unsupported format returns null instead of throwing', () {
    final data = FrameConversionData(
      width: width,
      height: height,
      format: ImageFormatGroup.unknown,
      quality: 80,
      planeBytes: [_yPlane(width, height, 180)],
      bytesPerRow: [width],
    );

    expect(convertFrameToJpeg(data), isNull);
  });

  test(
    'security: malformed/truncated plane data is caught and yields null instead of crashing the isolate',
    () {
      final data = FrameConversionData(
        width: width,
        height: height,
        format: ImageFormatGroup.nv21,
        quality: 80,
        planeBytes: [Uint8List(2)],
        bytesPerRow: [width],
      );

      expect(convertFrameToJpeg(data), isNull);
    },
  );
}
