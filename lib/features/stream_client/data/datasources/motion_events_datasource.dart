import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Consumes the server's `/events` SSE endpoint and emits a tick whenever
/// a motion alert arrives. Best-effort: any connection failure here must
/// never disrupt the underlying MJPEG video stream.
class MotionEventsDatasource {
  HttpClient? _client;
  StreamSubscription<String>? _subscription;
  final _motionController = StreamController<void>.broadcast();

  Stream<void> get motionEvents => _motionController.stream;

  Future<void> connect(String eventsUrl) async {
    disconnect();
    try {
      _client = HttpClient();
      final request = await _client!.getUrl(Uri.parse(eventsUrl));
      final response = await request.close();
      _subscription = response
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleLine, onError: (_) {}, cancelOnError: false);
    } catch (_) {}
  }

  void _handleLine(String line) {
    if (!line.startsWith('data:')) return;
    try {
      final decoded = jsonDecode(line.substring(5).trim());
      if (decoded is Map && decoded['type'] == 'motion') {
        _motionController.add(null);
      }
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
    _motionController.close();
  }
}
