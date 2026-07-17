import 'dart:async';
import 'dart:typed_data';

import '../../domain/repositories/stream_client_repository.dart';
import '../datasources/mjpeg_datasource.dart';

class StreamClientRepositoryImpl implements StreamClientRepository {
  StreamClientRepositoryImpl({required this._datasource});

  final MjpegClientDatasource _datasource;

  @override
  Stream<Uint8List> get frameStream => _datasource.frameStream;

  @override
  bool get isConnected => _datasource.isConnected;

  @override
  Future<void> connect(String url) => _datasource.connect(url);

  @override
  void disconnect() => _datasource.disconnect();

  @override
  void dispose() => _datasource.dispose();
}
