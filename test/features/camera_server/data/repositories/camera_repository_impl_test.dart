import 'dart:async';
import 'dart:typed_data';

import 'package:baby_monitor/features/camera_server/data/datasources/audio_datasource.dart';
import 'package:baby_monitor/features/camera_server/data/datasources/camera_datasource.dart';
import 'package:baby_monitor/features/camera_server/data/datasources/mjpeg_server.dart';
import 'package:baby_monitor/features/camera_server/data/datasources/native_camera_datasource.dart';
import 'package:baby_monitor/features/camera_server/data/repositories/camera_repository_impl.dart';
import 'package:baby_monitor/features/camera_server/domain/entities/stream_config.dart';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCameraDatasource extends Mock implements CameraDatasource {}

class MockMjpegServer extends Mock implements MjpegServer {}

class MockNativeCameraDatasource extends Mock implements NativeCameraDatasource {}

class MockAudioDatasource extends Mock implements AudioDatasource {}

void main() {
  late MockCameraDatasource cameraDatasource;
  late MockMjpegServer mjpegServer;
  late MockNativeCameraDatasource nativeCameraDatasource;
  late MockAudioDatasource audioDatasource;
  late CameraRepositoryImpl repository;

  const config = StreamConfig(
    quality: 75,
    targetFps: 8,
    port: 8080,
    lensDirection: CameraLensDirection.back,
    authToken: 'tok',
  );

  setUpAll(() {
    registerFallbackValue(const StreamConfig());
    registerFallbackValue(CameraLensDirection.back);
    registerFallbackValue(const Stream<Uint8List>.empty());
  });

  setUp(() async {
    cameraDatasource = MockCameraDatasource();
    mjpegServer = MockMjpegServer();
    nativeCameraDatasource = MockNativeCameraDatasource();
    audioDatasource = MockAudioDatasource();
    repository = CameraRepositoryImpl(
      cameraDatasource: cameraDatasource,
      mjpegServer: mjpegServer,
      nativeCameraDatasource: nativeCameraDatasource,
      audioDatasource: audioDatasource,
    );

    when(() => cameraDatasource.initialize(any())).thenAnswer((_) async {});
    when(() => mjpegServer.start(port: any(named: 'port'), authToken: any(named: 'authToken')))
        .thenAnswer((_) async {});
    await repository.initialize(config);
  });

  test(
    'success: backgrounding while streaming releases CameraX and switches the server to the native frame source',
    () async {
      when(() => cameraDatasource.isStreaming).thenReturn(true);
      when(() => cameraDatasource.dispose()).thenAnswer((_) async {});
      when(() => nativeCameraDatasource.acquireCamera(
            lensDirection: any(named: 'lensDirection'),
            width: any(named: 'width'),
            height: any(named: 'height'),
            quality: any(named: 'quality'),
            targetFps: any(named: 'targetFps'),
          )).thenAnswer((_) async {});
      when(() => nativeCameraDatasource.frameStream)
          .thenAnswer((_) => const Stream<Uint8List>.empty());

      await repository.handleAppBackgrounded();

      verify(() => cameraDatasource.dispose()).called(1);
      verify(() => nativeCameraDatasource.acquireCamera(
            lensDirection: CameraLensDirection.back,
            width: any(named: 'width'),
            height: any(named: 'height'),
            quality: 75,
            targetFps: 8,
          )).called(1);
      verify(() => mjpegServer.bindFrameStream(any())).called(1);
    },
  );

  test(
    'failure: backgrounding while not streaming is a no-op',
    () async {
      when(() => cameraDatasource.isStreaming).thenReturn(false);

      await repository.handleAppBackgrounded();

      verifyNever(() => cameraDatasource.dispose());
      verifyNever(() => nativeCameraDatasource.acquireCamera(
            lensDirection: any(named: 'lensDirection'),
            width: any(named: 'width'),
            height: any(named: 'height'),
            quality: any(named: 'quality'),
            targetFps: any(named: 'targetFps'),
          ));
    },
  );

  test(
    'security: foregrounding without an active background session never re-initializes the camera (avoids duplicate/ghost sessions)',
    () async {
      await repository.handleAppForegrounded();

      verifyNever(() => nativeCameraDatasource.releaseCamera());
      // Exactly the one call from repository.initialize() in setUp — no
      // extra reacquire triggered by a foreground event with nothing to undo.
      verify(() => cameraDatasource.initialize(any())).called(1);
    },
  );

  test(
    'security: foregrounding after a background session stops the native camera before reacquiring CameraX',
    () async {
      when(() => cameraDatasource.isStreaming).thenReturn(true);
      when(() => cameraDatasource.dispose()).thenAnswer((_) async {});
      when(() => nativeCameraDatasource.acquireCamera(
            lensDirection: any(named: 'lensDirection'),
            width: any(named: 'width'),
            height: any(named: 'height'),
            quality: any(named: 'quality'),
            targetFps: any(named: 'targetFps'),
          )).thenAnswer((_) async {});
      when(() => nativeCameraDatasource.frameStream)
          .thenAnswer((_) => const Stream<Uint8List>.empty());
      await repository.handleAppBackgrounded();

      when(() => nativeCameraDatasource.releaseCamera()).thenAnswer((_) async {});
      when(() => cameraDatasource.startImageStream())
          .thenAnswer((_) => const Stream<Uint8List>.empty());

      await repository.handleAppForegrounded();

      verify(() => nativeCameraDatasource.releaseCamera()).called(1);
      // Called twice: once by the initial repository.initialize() in setUp,
      // once more by handleAppForegrounded() reacquiring the camera.
      verify(() => cameraDatasource.initialize(config)).called(2);
      verify(() => cameraDatasource.startImageStream()).called(1);
    },
  );

  test(
    'success: starting streaming with mic permission granted captures and binds audio, '
    'and declares the microphone type to the foreground service',
    () async {
      when(() => cameraDatasource.startImageStream())
          .thenAnswer((_) => const Stream<Uint8List>.empty());
      when(() => audioDatasource.start())
          .thenAnswer((_) async => const Stream<Uint8List>.empty());
      when(() => nativeCameraDatasource.startService(
            micEnabled: any(named: 'micEnabled'),
          )).thenAnswer((_) async {});

      await repository.startStreaming();

      verify(() => mjpegServer.bindAudioStream(any())).called(1);
      verify(() => nativeCameraDatasource.startService(micEnabled: true))
          .called(1);
    },
  );

  test(
    'failure: a denied mic permission never blocks video streaming',
    () async {
      when(() => cameraDatasource.startImageStream())
          .thenAnswer((_) => const Stream<Uint8List>.empty());
      when(() => audioDatasource.start()).thenAnswer((_) async => null);
      when(() => nativeCameraDatasource.startService(
            micEnabled: any(named: 'micEnabled'),
          )).thenAnswer((_) async {});

      await repository.startStreaming();

      verify(() => mjpegServer.bindFrameStream(any())).called(1);
      verifyNever(() => mjpegServer.bindAudioStream(any()));
      verify(() => nativeCameraDatasource.startService(micEnabled: false))
          .called(1);
    },
  );

  test(
    'security: stopping/disposing always releases the microphone, even if it was never started',
    () async {
      when(() => audioDatasource.stop()).thenAnswer((_) async {});
      when(() => audioDatasource.dispose()).thenAnswer((_) async {});
      when(() => nativeCameraDatasource.stopService()).thenAnswer((_) async {});
      when(() => cameraDatasource.dispose()).thenAnswer((_) async {});
      when(() => mjpegServer.stop()).thenAnswer((_) async {});

      await repository.stopStreaming();
      await repository.dispose();

      verify(() => audioDatasource.stop()).called(1);
      verify(() => audioDatasource.dispose()).called(1);
    },
  );
}
