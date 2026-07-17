import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../../domain/entities/stream_config.dart';
import '../../domain/repositories/camera_repository.dart';
import 'camera_server_state.dart';

class CameraServerCubit extends Cubit<CameraServerState> {
  CameraServerCubit({required CameraRepository repository})
      : _repository = repository,
        super(const CameraServerState());

  final CameraRepository _repository;
  StreamSubscription? _clientCountSubscription;

  CameraController? get cameraController => _repository.cameraController;

  Future<void> initialize() async {
    emit(state.copyWith(status: CameraServerStatus.initializing));

    try {
      await _repository.initialize(state.config);

      final localIp = await _getLocalIp();
      final port = state.config.port;
      final streamUrl = 'http://$localIp:$port/stream';

      emit(state.copyWith(
        status: CameraServerStatus.initialized,
        localIp: localIp,
        port: port,
        streamUrl: streamUrl,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CameraServerStatus.error,
        errorMessage: _mapError(e),
      ));
    }
  }

  Future<void> startStreaming() async {
    try {
      await _repository.startStreaming();

      emit(state.copyWith(
        status: CameraServerStatus.streaming,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CameraServerStatus.error,
        errorMessage: _mapError(e),
      ));
    }
  }

  Future<void> stopStreaming() async {
    try {
      await _repository.stopStreaming();

      emit(state.copyWith(
        status: CameraServerStatus.stopped,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CameraServerStatus.error,
        errorMessage: _mapError(e),
      ));
    }
  }

  Future<void> toggleStreaming() async {
    if (state.status == CameraServerStatus.streaming) {
      await stopStreaming();
    } else if (state.status == CameraServerStatus.initialized ||
        state.status == CameraServerStatus.stopped) {
      await startStreaming();
    }
  }

  void updateConfig(StreamConfig config) {
    emit(state.copyWith(config: config));
  }

  void toggleCamera() {
    final newLensDirection = state.config.lensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    updateConfig(state.config.copyWith(lensDirection: newLensDirection));
  }

  Future<String> _getLocalIp() async {
    try {
      final info = NetworkInfo();
      final wifiIp = await info.getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty) {
        return wifiIp;
      }
    } catch (_) {}

    try {
      final info = NetworkInfo();
      final wifiIpv4 = await info.getWifiBroadcast();
      if (wifiIpv4 != null && wifiIpv4.isNotEmpty) {
        final parts = wifiIpv4.split('.');
        if (parts.length == 4) {
          return '${parts[0]}.${parts[1]}.${parts[2]}.1';
        }
      }
    } catch (_) {}

    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.address.startsWith('127.')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}

    return '0.0.0.0';
  }

  String _mapError(Object e) {
    final msg = e.toString();
    if (msg.contains('CameraAccessException')) {
      return 'No se pudo acceder a la camara. Verifica los permisos.';
    }
    if (msg.contains('Permission')) {
      return 'Se requieren permisos de camara.';
    }
    if (msg.contains('SocketException') || msg.contains('BindException')) {
      return 'No se pudo iniciar el servidor. Puerto ${state.config.port} en uso.';
    }
    return 'Error: $msg';
  }

  @override
  Future<void> close() {
    _clientCountSubscription?.cancel();
    _repository.dispose();
    return super.close();
  }
}
