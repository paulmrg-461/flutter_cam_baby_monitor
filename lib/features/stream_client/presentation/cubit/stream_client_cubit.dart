import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/stream_client_repository.dart';
import 'stream_client_state.dart';

class StreamClientCubit extends Cubit<StreamClientState> {
  StreamClientCubit({required this._repository})
    : super(const StreamClientState());

  final StreamClientRepository _repository;
  StreamSubscription<void>? _motionSubscription;

  Stream<Uint8List> get frameStream => _repository.frameStream;

  Future<void> connect(String url) async {
    emit(state.copyWith(
      status: StreamClientStatus.connecting,
      clearError: true,
    ));

    try {
      await _repository.connect(url);
      _listenForMotion();

      emit(state.copyWith(status: StreamClientStatus.connected));
    } catch (e) {
      emit(state.copyWith(
        status: StreamClientStatus.error,
        errorMessage: _mapError(e),
      ));
    }
  }

  void _listenForMotion() {
    _motionSubscription?.cancel();
    _motionSubscription = _repository.motionEvents.listen((_) {
      SystemSound.play(SystemSoundType.alert);
      emit(state.copyWith(motionTick: state.motionTick + 1));
    });
  }

  void disconnect() {
    _motionSubscription?.cancel();
    _motionSubscription = null;
    _repository.disconnect();
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
    _motionSubscription?.cancel();
    _repository.dispose();
    return super.close();
  }
}
