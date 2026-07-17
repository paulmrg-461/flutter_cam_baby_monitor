import 'dart:typed_data';

import 'package:baby_monitor/features/stream_client/data/services/audio_jitter_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AudioJitterBuffer', () {
    test(
      'success: primes only once enough audio has buffered, then yields it back in order',
      () {
        // 16kHz, 16-bit mono, 100ms prefill -> 3200 bytes needed.
        final buffer = AudioJitterBuffer(prefill: const Duration(milliseconds: 100));

        buffer.push(Uint8List(1000));
        expect(buffer.isPrimed, isFalse);
        expect(buffer.pull(500), isNull); // not primed yet: nothing released

        buffer.push(Uint8List(2200));
        expect(buffer.isPrimed, isTrue);

        final out = buffer.pull(500);
        expect(out, isNotNull);
        expect(out!.length, 500);
      },
    );

    test(
      'failure: pulling from an empty, never-fed buffer returns null instead of throwing',
      () {
        final buffer = AudioJitterBuffer();

        expect(() => buffer.pull(1000), returnsNormally);
        expect(buffer.pull(1000), isNull);
      },
    );

    test(
      'security: pull() never splits a 16-bit sample across two calls (odd byte counts)',
      () {
        final buffer = AudioJitterBuffer(prefill: Duration.zero);
        buffer.push(Uint8List.fromList(List<int>.generate(9, (i) => i)));

        final out = buffer.pull(5); // odd max: must round down to 4
        expect(out, isNotNull);
        expect(out!.length, 4);
        expect(buffer.bufferedBytes, 5);
      },
    );

    test('re-buffers to the prefill threshold after a full drain (underrun)', () {
      final buffer = AudioJitterBuffer(prefill: const Duration(milliseconds: 100));
      buffer.push(Uint8List(3200));
      expect(buffer.isPrimed, isTrue);

      final all = buffer.pull(3200);
      expect(all!.length, 3200);
      expect(buffer.isPrimed, isFalse); // drained to empty: must re-buffer

      buffer.push(Uint8List(1000));
      expect(buffer.pull(500), isNull); // still below prefill threshold
    });

    test('reset() clears buffered audio and un-primes', () {
      final buffer = AudioJitterBuffer(prefill: const Duration(milliseconds: 100));
      buffer.push(Uint8List(3200));
      expect(buffer.isPrimed, isTrue);

      buffer.reset();

      expect(buffer.isPrimed, isFalse);
      expect(buffer.bufferedBytes, 0);
      expect(buffer.pull(100), isNull);
    });
  });
}
