import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class MjpegServer {
  HttpServer? _server;
  final _clients = <HttpResponse>[];
  final _frameController = StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _frameSubscription;
  int _port = 8080;
  String _authToken = '';

  int get port => _port;
  bool get isRunning => _server != null;
  Stream<Uint8List> get frameStream => _frameController.stream;

  Future<void> start({int port = 8080, required String authToken}) async {
    _authToken = authToken;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _port = _server!.port;
    _server!.listen(_handleRequest);
  }

  bool _isAuthorized(HttpRequest request) {
    if (_authToken.isEmpty) return false;
    return request.uri.queryParameters['token'] == _authToken;
  }

  void _rejectUnauthorized(HttpRequest request) {
    request.response
      ..statusCode = HttpStatus.unauthorized
      ..headers.contentType = ContentType.text
      ..write('Unauthorized')
      ..close();
  }

  void bindFrameStream(Stream<Uint8List> frameStream) {
    _frameSubscription?.cancel();
    _frameSubscription = frameStream.listen((jpegData) {
      _frameController.add(jpegData);
    });
  }

  void _handleRequest(HttpRequest request) {
    if (!_isAuthorized(request)) {
      _rejectUnauthorized(request);
      return;
    }

    if (request.uri.path == '/stream') {
      _handleStreamRequest(request);
    } else if (request.uri.path == '/status') {
      _handleStatusRequest(request);
    } else {
      _handleRootRequest(request);
    }
  }

  void _handleStreamRequest(HttpRequest request) {
    final response = request.response;
    response.headers.set('Content-Type', 'multipart/x-mixed-replace; boundary=mjpegframe');
    response.headers.set('Cache-Control', 'no-cache, no-store, must-revalidate');
    response.headers.set('Pragma', 'no-cache');
    response.headers.set('Connection', 'close');
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('X-Content-Type-Options', 'nosniff');

    var isOpen = true;

    final subscription = _frameController.stream.listen(
      (jpegData) {
        if (isOpen) {
          try {
            response.write('--mjpegframe\r\n');
            response.write('Content-Type: image/jpeg\r\n');
            response.write('Content-Length: ${jpegData.length}\r\n\r\n');
            response.add(jpegData);
            response.write('\r\n');
          } catch (_) {
            isOpen = false;
          }
        }
      },
      onDone: () {
        isOpen = false;
        try {
          response.close();
        } catch (_) {}
      },
      onError: (_) {
        isOpen = false;
        try {
          response.close();
        } catch (_) {}
      },
    );

    response.done.then((_) {
      isOpen = false;
      subscription.cancel();
      _clients.remove(response);
    });

    _clients.add(response);
  }

  void _handleStatusRequest(HttpRequest request) {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write('{"status":"running","clients":${_clients.length},"port":$_port}')
      ..close();
  }

  void _handleRootRequest(HttpRequest request) {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(_htmlPage)
      ..close();
  }

  String get _htmlPage => '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Baby Monitor</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { background: #0D0D0D; display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 100vh; font-family: system-ui, sans-serif; }
    h1 { color: #E0E0E0; margin-bottom: 16px; font-size: 1.5rem; }
    img { max-width: 95vw; max-height: 85vh; border-radius: 12px; box-shadow: 0 4px 24px rgba(0,0,0,0.5); }
    .status { color: #81C784; margin-top: 12px; font-size: 0.85rem; }
  </style>
</head>
<body>
  <h1>Baby Monitor</h1>
  <img src="/stream?token=$_authToken" alt="Stream" />
  <p class="status">Conectado | puerto $_port</p>
</body>
</html>
''';

  Future<void> stop() async {
    _frameSubscription?.cancel();
    _frameSubscription = null;

    for (final client in _clients) {
      try {
        await client.close();
      } catch (_) {}
    }
    _clients.clear();

    await _server?.close(force: true);
    _server = null;

    await _frameController.close();
  }
}
