import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/mjpeg_datasource.dart';
import 'stream_client_state.dart';

class StreamClientCubit extends Cubit<StreamClientState> {
  StreamClientCubit({required MjpegClientDatasource datasource})
      : _datasource = datasource,
        super(const StreamClientState());

  final MjpegClientDatasource _datasource;

  Stream<Uint8List> get frameStream => _datasource.frameStream;

  Future<void> connect(String url) async {
    emit(state.copyWith(
      status: StreamClientStatus.connecting,
      clearError: true,
    ));

    try {
      await _datasource.connect(url);

      emit(state.copyWith(status: StreamClientStatus.connected));
    } catch (e) {
      emit(state.copyWith(
        status: StreamClientStatus.error,
        errorMessage: _mapError(e),
      ));
    }
  }

  void disconnect() {
    _datasource.disconnect();
    emit(state.copyWith(status: StreamClientStatus.disconnected));
  }

  String _mapError(Object e) {
    final msg = e.toString();
    if (msg.contains('Connection refused') || msg.contains('SocketException')) {
      return 'No se pudo conectar al servidor. Verifica la IP y que el servidor este activo.';
    }
    if (msg.contains('Timeout')) {
      return 'Tiempo de conexion agotado.';
    }
    return 'Error de conexion: $msg';
  }

  @override
  Future<void> close() {
    _datasource.dispose();
    return super.close();
  }
}
