import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../services/motion_detector.dart';

class MjpegServer {
  MjpegServer({MotionDetector? motionDetector})
      : _motionDetector = motionDetector ?? MotionDetector();

  HttpServer? _server;
  final _clients = <HttpResponse>[];
  final _eventClients = <HttpResponse>[];
  final _audioClients = <HttpResponse>[];
  final _frameController = StreamController<Uint8List>.broadcast();
  final _audioController = StreamController<Uint8List>.broadcast();
  final MotionDetector _motionDetector;
  StreamSubscription<Uint8List>? _frameSubscription;
  StreamSubscription<Uint8List>? _audioSubscription;
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
    // A new source (e.g. CameraX <-> native Camera2 handoff) means the
    // previous reference frame is no longer comparable.
    _motionDetector.reset();
    _frameSubscription = frameStream.listen((jpegData) {
      _frameController.add(jpegData);
      if (_motionDetector.feed(jpegData)) {
        _broadcastMotionEvent();
      }
    });
  }

  /// Feeds raw PCM16 audio chunks (from [AudioDatasource]) to any
  /// connected `/audio` clients. Independent of [bindFrameStream]: audio
  /// capture has no CameraX-style lifecycle coupling, so it isn't reset or
  /// re-bound on the background/foreground camera handoff.
  void bindAudioStream(Stream<Uint8List> audioStream) {
    _audioSubscription?.cancel();
    _audioSubscription = audioStream.listen((chunk) {
      _audioController.add(chunk);
    });
  }

  void _handleRequest(HttpRequest request) {
    if (!_isAuthorized(request)) {
      _rejectUnauthorized(request);
      return;
    }

    if (request.uri.path == '/stream') {
      _handleStreamRequest(request);
    } else if (request.uri.path == '/audio') {
      _handleAudioRequest(request);
    } else if (request.uri.path == '/status') {
      _handleStatusRequest(request);
    } else if (request.uri.path == '/events') {
      _handleEventsRequest(request);
    } else {
      _handleRootRequest(request);
    }
  }

  void _handleAudioRequest(HttpRequest request) {
    final response = request.response;
    response.headers.set('Content-Type', 'audio/L16;rate=16000;channels=1');
    response.headers.set('Cache-Control', 'no-cache, no-store, must-revalidate');
    response.headers.set('Connection', 'keep-alive');
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.bufferOutput = false;

    var isOpen = true;
    // dart:io holds response headers back until the first non-empty body
    // write (a zero-length add() is a no-op that never touches the
    // socket). Without this, a client's request.close() hangs until real
    // audio actually starts flowing, which can be seconds after the mic
    // finishes initializing. Two zero bytes = one silent PCM16 sample —
    // inaudible, and forces the headers out immediately.
    try {
      response.add(Uint8List(2));
    } catch (_) {
      isOpen = false;
    }

    final subscription = _audioController.stream.listen(
      (chunk) {
        if (!isOpen) return;
        try {
          response.add(chunk);
        } catch (_) {
          isOpen = false;
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
      _audioClients.remove(response);
    });

    _audioClients.add(response);
  }

  void _handleEventsRequest(HttpRequest request) {
    final response = request.response;
    response.headers.set('Content-Type', 'text/event-stream');
    response.headers.set('Cache-Control', 'no-cache, no-store, must-revalidate');
    response.headers.set('Connection', 'keep-alive');
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.bufferOutput = false;

    _eventClients.add(response);
    try {
      response.write(': connected\n\n');
    } catch (_) {
      _eventClients.remove(response);
      return;
    }

    response.done.then((_) {
      _eventClients.remove(response);
    });
  }

  void _broadcastMotionEvent() {
    final payload =
        '{"type":"motion","ts":${DateTime.now().millisecondsSinceEpoch}}';
    final chunk = 'data: $payload\n\n';
    for (final client in List<HttpResponse>.from(_eventClients)) {
      try {
        client.write(chunk);
      } catch (_) {
        _eventClients.remove(client);
      }
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
    .frame { position: relative; }
    img { max-width: 95vw; max-height: 75vh; border-radius: 12px; box-shadow: 0 4px 24px rgba(0,0,0,0.5); display: block; }
    .motion-alert { position: absolute; inset: 0; border: 4px solid #EF5350; border-radius: 12px; opacity: 0; transition: opacity 0.2s ease; pointer-events: none; }
    .status { color: #81C784; margin-top: 12px; font-size: 0.85rem; }
    #soundBtn { margin-top: 16px; padding: 10px 20px; border-radius: 24px; border: none; background: #2C2C2C; color: #E0E0E0; font-size: 0.9rem; }
    #soundBtn:disabled { background: #1B5E20; color: #A5D6A7; }
  </style>
</head>
<body>
  <h1>Baby Monitor</h1>
  <div class="frame">
    <img src="/stream?token=$_authToken" alt="Stream" />
    <div class="motion-alert" id="motionAlert"></div>
  </div>
  <p class="status">Conectado | puerto $_port</p>
  <button id="soundBtn">Activar sonido de alerta</button>
  <script>
    let audioCtx = null;
    let soundEnabled = false;
    const soundBtn = document.getElementById('soundBtn');
    const motionAlert = document.getElementById('motionAlert');

    soundBtn.onclick = () => {
      audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
      audioCtx.resume();
      soundEnabled = true;
      soundBtn.textContent = 'Sonido activado';
      soundBtn.disabled = true;
    };

    function beep() {
      if (!soundEnabled || !audioCtx) return;
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.type = 'sine';
      osc.frequency.value = 880;
      gain.gain.value = 0.3;
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start();
      osc.stop(audioCtx.currentTime + 0.4);
    }

    function flashMotion() {
      motionAlert.style.opacity = '1';
      setTimeout(() => { motionAlert.style.opacity = '0'; }, 1500);
    }

    const events = new EventSource('/events?token=$_authToken');
    events.onmessage = (e) => {
      try {
        const data = JSON.parse(e.data);
        if (data.type === 'motion') {
          beep();
          flashMotion();
        }
      } catch (err) {}
    };
  </script>
</body>
</html>
''';

  Future<void> stop() async {
    _frameSubscription?.cancel();
    _frameSubscription = null;
    _audioSubscription?.cancel();
    _audioSubscription = null;

    for (final client in List<HttpResponse>.from(_clients)) {
      try {
        await client.close();
      } catch (_) {}
    }
    _clients.clear();

    for (final client in List<HttpResponse>.from(_eventClients)) {
      try {
        await client.close();
      } catch (_) {}
    }
    _eventClients.clear();

    for (final client in List<HttpResponse>.from(_audioClients)) {
      try {
        await client.close();
      } catch (_) {}
    }
    _audioClients.clear();

    await _server?.close(force: true);
    _server = null;

    await _frameController.close();
    await _audioController.close();
  }
}
