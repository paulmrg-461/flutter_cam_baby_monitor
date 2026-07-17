import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../../../../core/background/background_service_controller.dart';
import '../../../../core/security/token_storage.dart';
import '../../domain/entities/stream_config.dart';
import '../../domain/repositories/camera_repository.dart';
import 'camera_server_state.dart';

class CameraServerCubit extends Cubit<CameraServerState>
    with WidgetsBindingObserver {
  CameraServerCubit({required this._repository, required this._tokenStorage})
      : super(const CameraServerState()) {
    WidgetsBinding.instance.addObserver(this);
  }

  final CameraRepository _repository;
  final TokenStorage _tokenStorage;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (this.state.status != CameraServerStatus.streaming) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // Emit first: drops the UI's reference to the CameraController before
      // handleAppBackgrounded() disposes it, so no widget tries to repaint
      // an already-disposed controller.
      emit(this.state.copyWith(isBackgroundCapture: true));
      _repository.handleAppBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      _repository.handleAppForegrounded().then((_) {
        // Emit only once the new controller is ready, so the UI never sees
        // an intermediate not-yet-initialized one.
        if (!isClosed) emit(this.state.copyWith(isBackgroundCapture: false));
      });
    }
  }

  CameraController? get cameraController => _repository.cameraController;

  Future<void> initialize() async {
    final token = await _tokenStorage.getOrCreateToken();
    await _initializeWith(token);
  }

  Future<void> regenerateToken() async {
    if (state.status == CameraServerStatus.initial ||
        state.status == CameraServerStatus.initializing) {
      return;
    }
    await _repository.dispose();
    final token = await _tokenStorage.regenerateToken();
    await _initializeWith(token);
  }

  Future<void> _initializeWith(String token) async {
    emit(state.copyWith(status: CameraServerStatus.initializing));

    try {
      final config = state.config.copyWith(authToken: token);
      await _repository.initialize(config);

      final localIp = await _getLocalIp();
      final port = config.port;
      final base = 'http://$localIp:$port';
      final streamUrl = '$base/stream?token=${config.authToken}';
      final browserUrl = '$base/?token=${config.authToken}';

      emit(state.copyWith(
        status: CameraServerStatus.initialized,
        config: config,
        localIp: localIp,
        port: port,
        streamUrl: streamUrl,
        browserUrl: browserUrl,
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
      await BackgroundServiceController.requestPermissions();

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
    final wifiIp = await _getWifiIp();
    if (wifiIp != null) return wifiIp;

    final broadcastIp = await _getWifiBroadcastGatewayIp();
    if (broadcastIp != null) return broadcastIp;

    final interfaceIp = await _getFirstInterfaceIp();
    if (interfaceIp != null) return interfaceIp;

    return '0.0.0.0';
  }

  Future<String?> _getWifiIp() async {
    try {
      final wifiIp = await NetworkInfo().getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty) return wifiIp;
    } catch (_) {}
    return null;
  }

  Future<String?> _getWifiBroadcastGatewayIp() async {
    try {
      final broadcast = await NetworkInfo().getWifiBroadcast();
      if (broadcast == null || broadcast.isEmpty) return null;
      final parts = broadcast.split('.');
      if (parts.length != 4) return null;
      return '${parts[0]}.${parts[1]}.${parts[2]}.1';
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getFirstInterfaceIp() async {
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
    return null;
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
    WidgetsBinding.instance.removeObserver(this);
    _repository.dispose();
    return super.close();
  }
}
