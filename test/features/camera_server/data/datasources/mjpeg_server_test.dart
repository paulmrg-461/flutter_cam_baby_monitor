import 'dart:convert';
import 'dart:io';

import 'package:baby_monitor/features/camera_server/data/datasources/mjpeg_server.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
