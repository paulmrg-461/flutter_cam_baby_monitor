import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Consumes the server's `/audio` endpoint: a continuous raw PCM16 byte
/// stream (no framing, unlike the MJPEG multipart video stream). Best
/// effort — connection failures here must never disrupt the video stream.
class AudioClientDatasource {
  HttpClient? _client;
  StreamSubscription<List<int>>? _subscription;
  final _audioController = StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get audioStream => _audioController.stream;

  Future<void> connect(String url) async {
    disconnect();
    try {
      _client = HttpClient();
      final request = await _client!.getUrl(Uri.parse(url));
      final response = await request.close();
      _subscription = response.listen(
        (chunk) => _audioController.add(Uint8List.fromList(chunk)),
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {}
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _client?.close(force: true);
    _client = null;
  }

  void dispose() {
    disconnect();
    _audioController.close();
  }
}
