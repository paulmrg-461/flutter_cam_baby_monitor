import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class MjpegClientDatasource {
  HttpClient? _client;
  StreamSubscription? _subscription;
  final _frameController = StreamController<Uint8List>.broadcast();
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;
  static const _reconnectDelay = Duration(seconds: 2);

  Stream<Uint8List> get frameStream => _frameController.stream;

  bool get isConnected => _client != null;

  Future<void> connect(String url) async {
    _reconnectAttempts = 0;
    await _connectInternal(url);
  }

  Future<void> _connectInternal(String url) async {
    try {
      _client?.close(force: true);
      _client = HttpClient();
      _client!.connectionTimeout = const Duration(seconds: 5);

      final uri = Uri.parse(url);
      final request = await _client!.getUrl(uri);
      request.headers.set('Cache-Control', 'no-cache');
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Server returned ${response.statusCode}');
      }

      final contentType = response.headers.contentType;
      if (contentType == null ||
          !contentType.value.contains('multipart/x-mixed-replace')) {
        throw HttpException('Invalid content type: $contentType');
      }

      final boundary = contentType.parameters['boundary'];
      if (boundary == null) {
        throw HttpException('No boundary found in content type');
      }

      _subscription = response.listen(
        (data) => _processData(data, boundary),
        onError: (error) {
          _frameController.addError(error);
          _tryReconnect(url);
        },
        onDone: () => _tryReconnect(url),
        cancelOnError: false,
      );
    } catch (e) {
      _frameController.addError(e);
      _tryReconnect(url);
    }
  }

  final _buffer = <int>[];
  bool _processingHeader = true;
  int _contentLength = 0;

  void _processData(List<int> data, String boundary) {
    final boundaryPattern = '--$boundary'.codeUnits;
    final crlfcrlf = [13, 10, 13, 10];

    _buffer.addAll(data);

    while (_buffer.isNotEmpty) {
      if (_processingHeader) {
        final headerEnd = _findSequence(_buffer, crlfcrlf);
        if (headerEnd == -1) return;

        final headerData = _buffer.sublist(0, headerEnd);
        _buffer.removeRange(0, headerEnd + crlfcrlf.length);
        _processingHeader = false;

        _contentLength = 0;
        final headerStr = String.fromCharCodes(headerData);
        for (final line in headerStr.split('\r\n')) {
          if (line.toLowerCase().startsWith('content-length:')) {
            _contentLength =
                int.tryParse(line.substring('content-length:'.length).trim()) ??
                    0;
          }
        }
      } else {
        if (_contentLength > 0) {
          if (_buffer.length < _contentLength) return;

          final frameData = Uint8List.fromList(
            _buffer.sublist(0, _contentLength),
          );
          _buffer.removeRange(0, _contentLength);

          if (frameData.isNotEmpty) {
            _frameController.add(frameData);
          }
        } else {
          final nextBoundary = _findSequence(_buffer, boundaryPattern);
          if (nextBoundary == -1) return;

          if (nextBoundary > 0) {
            final frameData = Uint8List.fromList(
              _buffer.sublist(0, nextBoundary),
            );
            if (frameData.isNotEmpty) {
              _frameController.add(frameData);
            }
          }

          final boundaryEnd = nextBoundary + boundaryPattern.length;
          if (boundaryEnd < _buffer.length &&
              _buffer[boundaryEnd] == 13 &&
              boundaryEnd + 1 < _buffer.length &&
              _buffer[boundaryEnd + 1] == 10) {
            _buffer.removeRange(0, boundaryEnd + 2);
          } else {
            _buffer.removeRange(0, boundaryEnd);
          }
        }

        _processingHeader = true;
        _contentLength = 0;
      }
    }
  }

  int _findSequence(List<int> data, List<int> pattern) {
    outer:
    for (var i = 0; i <= data.length - pattern.length; i++) {
      for (var j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  void _tryReconnect(String url) {
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      Future.delayed(_reconnectDelay, () {
        _connectInternal(url);
      });
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _client?.close(force: true);
    _client = null;
    _buffer.clear();
    _processingHeader = true;
    _reconnectAttempts = _maxReconnectAttempts;
  }

  void dispose() {
    disconnect();
    _frameController.close();
  }
}
