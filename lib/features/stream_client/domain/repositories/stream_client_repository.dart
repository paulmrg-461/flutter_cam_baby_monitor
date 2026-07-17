import 'dart:async';
import 'dart:typed_data';

abstract class StreamClientRepository {
  Stream<Uint8List> get frameStream;

  /// Ticks whenever the server reports a motion detection alert.
  Stream<void> get motionEvents;
  bool get isConnected;
  Future<void> connect(String url);
  void disconnect();
  void dispose();
}
