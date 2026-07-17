import 'dart:async';
import 'dart:typed_data';

abstract class StreamClientRepository {
  Stream<Uint8List> get frameStream;
  bool get isConnected;
  Future<void> connect(String url);
  void disconnect();
  void dispose();
}
