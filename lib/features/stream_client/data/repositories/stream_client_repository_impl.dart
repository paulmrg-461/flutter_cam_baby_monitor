import 'dart:async';
import 'dart:typed_data';

import '../../domain/repositories/stream_client_repository.dart';
import '../datasources/audio_client_datasource.dart';
import '../datasources/mjpeg_datasource.dart';
import '../datasources/motion_events_datasource.dart';
import '../services/pcm_audio_player.dart';

class StreamClientRepositoryImpl implements StreamClientRepository {
  StreamClientRepositoryImpl({
    required this._datasource,
    required this._motionDatasource,
    required this._audioDatasource,
    required this._audioPlayer,
  });

  final MjpegClientDatasource _datasource;
  final MotionEventsDatasource _motionDatasource;
  final AudioClientDatasource _audioDatasource;
  final PcmAudioPlayer _audioPlayer;
  StreamSubscription<Uint8List>? _audioSubscription;

  @override
  Stream<Uint8List> get frameStream => _datasource.frameStream;

  @override
  Stream<void> get motionEvents => _motionDatasource.motionEvents;

  @override
  bool get isConnected => _datasource.isConnected;

  @override
  Future<void> connect(String url) async {
    await _datasource.connect(url);

    final eventsUrl = _deriveUrl(url, '/events');
    if (eventsUrl != null) {
      unawaited(_motionDatasource.connect(eventsUrl));
    }

    final audioUrl = _deriveUrl(url, '/audio');
    if (audioUrl != null) {
      await _audioPlayer.start();
      _audioSubscription?.cancel();
      _audioSubscription = _audioDatasource.audioStream.listen(_audioPlayer.feed);
      unawaited(_audioDatasource.connect(audioUrl));
    }
  }

  @override
  void disconnect() {
    _datasource.disconnect();
    _motionDatasource.disconnect();
    _audioSubscription?.cancel();
    _audioSubscription = null;
    _audioDatasource.disconnect();
    unawaited(_audioPlayer.stop());
  }

  @override
  void dispose() {
    _datasource.dispose();
    _motionDatasource.dispose();
    _audioSubscription?.cancel();
    _audioDatasource.dispose();
    unawaited(_audioPlayer.stop());
  }

  String? _deriveUrl(String streamUrl, String path) {
    try {
      return Uri.parse(streamUrl).replace(path: path).toString();
    } catch (_) {
      return null;
    }
  }
}
