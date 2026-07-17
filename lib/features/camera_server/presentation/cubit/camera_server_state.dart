import 'package:equatable/equatable.dart';

import '../../domain/entities/stream_config.dart';

enum CameraServerStatus { initial, initializing, initialized, streaming, error, stopped }

class CameraServerState extends Equatable {
  final CameraServerStatus status;
  final StreamConfig config;
  final String? localIp;
  final int? port;
  final String? streamUrl;
  final String? browserUrl;
  final String? errorMessage;

  const CameraServerState({
    this.status = CameraServerStatus.initial,
    this.config = const StreamConfig(),
    this.localIp,
    this.port,
    this.streamUrl,
    this.browserUrl,
    this.errorMessage,
  });

  CameraServerState copyWith({
    CameraServerStatus? status,
    StreamConfig? config,
    String? localIp,
    int? port,
    String? streamUrl,
    String? browserUrl,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CameraServerState(
      status: status ?? this.status,
      config: config ?? this.config,
      localIp: localIp ?? this.localIp,
      port: port ?? this.port,
      streamUrl: streamUrl ?? this.streamUrl,
      browserUrl: browserUrl ?? this.browserUrl,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        config,
        localIp,
        port,
        streamUrl,
        browserUrl,
        errorMessage,
      ];
}
