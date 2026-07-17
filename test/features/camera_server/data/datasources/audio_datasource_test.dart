import 'dart:async';
import 'dart:typed_data';

import 'package:baby_monitor/features/camera_server/data/datasources/audio_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';

class MockAudioRecorder extends Mock implements AudioRecorder {}

void main() {
  late MockAudioRecorder recorder;
  late AudioDatasource datasource;

  setUpAll(() {
    registerFallbackValue(const RecordConfig());
  });

  setUp(() {
    recorder = MockAudioRecorder();
    datasource = AudioDatasource(recorder: recorder);
  });

  test(
    'success: with permission granted, start() captures pcm16 mono at 16kHz',
    () async {
      when(() => recorder.hasPermission()).thenAnswer((_) async => true);
      when(() => recorder.startStream(any()))
          .thenAnswer((_) async => const Stream<Uint8List>.empty());

      final stream = await datasource.start();

      expect(stream, isNotNull);
      expect(datasource.isRecording, isTrue);
      final captured = verify(() => recorder.startStream(captureAny())).captured;
      final config = captured.single as RecordConfig;
      expect(config.encoder, AudioEncoder.pcm16bits);
      expect(config.sampleRate, 16000);
      expect(config.numChannels, 1);
    },
  );

  test(
    'failure: without microphone permission, start() returns null and never opens the mic',
    () async {
      when(() => recorder.hasPermission()).thenAnswer((_) async => false);

      final stream = await datasource.start();

      expect(stream, isNull);
      expect(datasource.isRecording, isFalse);
      verifyNever(() => recorder.startStream(any()));
    },
  );

  test(
    'security: dispose() always releases the recorder even if never started',
    () async {
      when(() => recorder.dispose()).thenAnswer((_) async {});

      await datasource.dispose();

      verifyNever(() => recorder.stop());
      verify(() => recorder.dispose()).called(1);
    },
  );

  test(
    'security: dispose() stops an active recording before releasing the recorder',
    () async {
      when(() => recorder.hasPermission()).thenAnswer((_) async => true);
      when(() => recorder.startStream(any()))
          .thenAnswer((_) async => const Stream<Uint8List>.empty());
      when(() => recorder.stop()).thenAnswer((_) async => null);
      when(() => recorder.dispose()).thenAnswer((_) async {});

      await datasource.start();
      await datasource.dispose();

      expect(datasource.isRecording, isFalse);
      verify(() => recorder.stop()).called(1);
      verify(() => recorder.dispose()).called(1);
    },
  );
}
