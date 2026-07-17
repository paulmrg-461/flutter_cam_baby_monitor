import 'dart:async';
import 'dart:typed_data';

import '../../domain/repositories/stream_client_repository.dart';
import '../datasources/mjpeg_datasource.dart';
import '../datasources/motion_events_datasource.dart';

class StreamClientRepositoryImpl implements StreamClientRepository {
  StreamClientRepositoryImpl({
    required this._datasource,
    required this._motionDatasource,
  });

  final MjpegClientDatasource _datasource;
  final MotionEventsDatasource _motionDatasource;

  @override
  Stream<Uint8List> get frameStream => _datasource.frameStream;

  @override
  Stream<void> get motionEvents => _motionDatasource.motionEvents;

  @override
  bool get isConnected => _datasource.isConnected;

  @override
  Future<void> connect(String url) async {
    await _datasource.connect(url);
    final eventsUrl = _deriveEventsUrl(url);
    if (eventsUrl != null) {
      unawaited(_motionDatasource.connect(eventsUrl));
    }
  }

  @override
  void disconnect() {
    _datasource.disconnect();
    _motionDatasource.disconnect();
  }

  @override
  void dispose() {
    _datasource.dispose();
    _motionDatasource.dispose();
  }

  String? _deriveEventsUrl(String streamUrl) {
    try {
      return Uri.parse(streamUrl).replace(path: '/events').toString();
    } catch (_) {
      return null;
    }
  }
}
