import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:baby_monitor/features/camera_server/data/datasources/mjpeg_server.dart';
import 'package:baby_monitor/features/camera_server/data/services/motion_detector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _solidJpeg(img.Color color, {int width = 96, int height = 72}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: color);
  return img.encodeJpg(image);
}

void main() {
  late MjpegServer server;
  const token = 'test-token-123';

  setUp(() async {
    server = MjpegServer();
    await server.start(port: 0, authToken: token);
  });

  tearDown(() async {
    await server.stop();
  });

  Future<HttpClientResponse> hit(String path) async {
    final client = HttpClient();
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:${server.port}$path'),
    );
    final response = await request.close();
    client.close(force: true);
    return response;
  }

  test('success: request with the correct token is accepted', () async {
    final response = await hit('/status?token=$token');
    final body = await response.transform(utf8.decoder).join();

    expect(response.statusCode, HttpStatus.ok);
    expect(body, contains('"status":"running"'));
  });

  test('failure: request without a token is rejected with 401', () async {
    final response = await hit('/status');

    expect(response.statusCode, HttpStatus.unauthorized);
  });

  test('security: a wrong token is rejected the same as no token', () async {
    final response = await hit('/status?token=wrong');

    expect(response.statusCode, HttpStatus.unauthorized);
  });

  test('security: the video stream endpoint is also gated by the token', () async {
    final response = await hit('/stream');

    expect(response.statusCode, HttpStatus.unauthorized);
  });

  test('security: the motion events endpoint is also gated by the token', () async {
    final response = await hit('/events');

    expect(response.statusCode, HttpStatus.unauthorized);
  });

  test('security: the audio endpoint is also gated by the token', () async {
    final response = await hit('/audio');

    expect(response.statusCode, HttpStatus.unauthorized);
  });

  test(
    'success: audio chunks bound via bindAudioStream reach connected /audio clients',
    () async {
      final audioClient = HttpClient();
      final request = await audioClient.getUrl(
        Uri.parse('http://127.0.0.1:${server.port}/audio?token=$token'),
      );
      final response = await request.close();
      addTearDown(audioClient.close);

      final received = StreamController<List<int>>();
      response.listen(received.add);

      final chunks = StreamController<Uint8List>();
      server.bindAudioStream(chunks.stream);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      chunks.add(Uint8List.fromList([1, 2, 3, 4]));

      // The server primes the connection with 2 bytes of silence to force
      // headers out immediately (see _handleAudioRequest); skip past that
      // to find our actual test payload.
      final firstChunk = await received.stream
          .firstWhere((c) => c.length == 4)
          .timeout(const Duration(seconds: 5));

      expect(firstChunk, [1, 2, 3, 4]);
      await chunks.close();
    },
  );

  test(
    'success: a motion trigger is broadcast as an SSE message to connected /events clients',
    () async {
      final motionServer = MjpegServer(
        motionDetector: MotionDetector(cooldown: Duration.zero),
      );
      await motionServer.start(port: 0, authToken: token);
      addTearDown(motionServer.stop);

      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${motionServer.port}/events?token=$token'),
      );
      final response = await request.close();
      final lines = StreamController<String>();
      response.transform(utf8.decoder).listen(lines.add);
      addTearDown(client.close);

      final frames = StreamController<Uint8List>();
      motionServer.bindFrameStream(frames.stream);

      frames.add(_solidJpeg(img.ColorRgb8(20, 20, 20)));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      frames.add(_solidJpeg(img.ColorRgb8(230, 230, 230)));

      final chunk = await lines.stream
          .firstWhere((line) => line.contains('"type":"motion"'))
          .timeout(const Duration(seconds: 5));

      expect(chunk, contains('data:'));
      await frames.close();
    },
  );
}
