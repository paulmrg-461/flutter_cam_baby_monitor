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
  <button id="soundBtn">Activar sonido</button>
  <script>
    const AUDIO_SAMPLE_RATE = 16000;
    const AUDIO_PREFILL_SEC = 0.3; // robustness over latency: same call as the Flutter client's jitter buffer

    let audioCtx = null;
    let soundEnabled = false;
    let nextPlayTime = 0;
    let leftoverByte = null; // odd byte carried across fetch chunks (16-bit samples can't split)
    const soundBtn = document.getElementById('soundBtn');
    const motionAlert = document.getElementById('motionAlert');

    // Without a user gesture, Chrome's autoplay policy leaves
    // resume()'s promise permanently pending (it does not reject) —
    // so this must never be `await`-ed behind a guard that blocks later
    // calls. Each call fires its own resume() attempt and only the one
    // that actually lands during a real gesture will resolve to
    // 'running'; whichever gets there first wins via the soundEnabled
    // check inside .then().
    function enableSound() {
      if (soundEnabled) return;
      audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
      audioCtx.resume().then(() => {
        if (soundEnabled || audioCtx.state !== 'running') return;
        soundEnabled = true;
        soundBtn.textContent = 'Sonido activado';
        soundBtn.disabled = true;
        startAudioStream();
      }).catch(() => {});
    }

    soundBtn.onclick = enableSound;

    // Best-effort on load (works in some PWA/installed contexts); on
    // regular Chrome tabs this stays pending until the listeners below
    // catch the user's first real tap/click anywhere on the page.
    enableSound();
    document.addEventListener('click', enableSound);
    document.addEventListener('touchend', enableSound);

    // Screen Wake Lock: keeps the display on while this page is open.
    // The API requires a secure context (https, or localhost) — it's
    // unavailable on a plain http://<lan-ip> origin, which is how this
    // server is normally reached. Fall back to a muted, always-playing
    // video: most browsers/OSes suppress screen dimming/locking while
    // media is actively playing, regardless of scheme.
    let wakeLock = null;
    let wakeVideo = null;

    function createNoSleepVideo() {
      const canvas = document.createElement('canvas');
      canvas.width = 1;
      canvas.height = 1;
      canvas.getContext('2d').fillRect(0, 0, 1, 1);
      const video = document.createElement('video');
      video.muted = true;
      video.setAttribute('muted', '');
      video.setAttribute('playsinline', '');
      video.style.cssText = 'position:fixed;width:1px;height:1px;opacity:0;pointer-events:none;';
      video.srcObject = canvas.captureStream(1);
      document.body.appendChild(video);
      return video;
    }

    async function requestWakeLock() {
      try {
        if ('wakeLock' in navigator) {
          wakeLock = await navigator.wakeLock.request('screen');
          return;
        }
      } catch (err) {}
      wakeVideo = wakeVideo || createNoSleepVideo();
      wakeVideo.play().catch(() => {});
    }
    requestWakeLock();
    document.addEventListener('click', requestWakeLock);
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible') requestWakeLock();
    });

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

    function playPcmChunk(bytes) {
      let data = bytes;
      if (leftoverByte !== null) {
        const merged = new Uint8Array(data.length + 1);
        merged[0] = leftoverByte;
        merged.set(data, 1);
        data = merged;
        leftoverByte = null;
      }
      if (data.length % 2 !== 0) {
        leftoverByte = data[data.length - 1];
        data = data.subarray(0, data.length - 1);
      }
      if (data.length === 0) return;

      const view = new DataView(data.buffer, data.byteOffset, data.length);
      const sampleCount = data.length / 2;
      const float32 = new Float32Array(sampleCount);
      for (let i = 0; i < sampleCount; i++) {
        float32[i] = view.getInt16(i * 2, true) / 32768;
      }

      const buffer = audioCtx.createBuffer(1, sampleCount, AUDIO_SAMPLE_RATE);
      buffer.copyToChannel(float32, 0);
      const source = audioCtx.createBufferSource();
      source.buffer = buffer;
      source.connect(audioCtx.destination);

      const now = audioCtx.currentTime;
      if (nextPlayTime < now + 0.05) {
        nextPlayTime = now + AUDIO_PREFILL_SEC; // fell behind: re-buffer instead of glitching
      }
      source.start(nextPlayTime);
      nextPlayTime += buffer.duration;
    }

    async function startAudioStream() {
      try {
        const resp = await fetch('/audio?token=$_authToken');
        const reader = resp.body.getReader();
        while (true) {
          const result = await reader.read();
          if (result.done) break;
          if (soundEnabled && result.value && result.value.length) {
            playPcmChunk(result.value);
          }
        }
      } catch (err) {
        console.error('audio stream error', err);
      }
    }
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
