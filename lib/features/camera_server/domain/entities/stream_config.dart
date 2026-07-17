import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';

class StreamConfig extends Equatable {
  final ResolutionPreset resolution;
  final int quality;
  final int targetFps;
  final int port;
  final CameraLensDirection lensDirection;

  const StreamConfig({
    this.resolution = ResolutionPreset.medium,
    this.quality = 80,
    this.targetFps = 10,
    this.port = 8080,
    this.lensDirection = CameraLensDirection.back,
  });

  StreamConfig copyWith({
    ResolutionPreset? resolution,
    int? quality,
    int? targetFps,
    int? port,
    CameraLensDirection? lensDirection,
  }) {
    return StreamConfig(
      resolution: resolution ?? this.resolution,
      quality: quality ?? this.quality,
      targetFps: targetFps ?? this.targetFps,
      port: port ?? this.port,
      lensDirection: lensDirection ?? this.lensDirection,
    );
  }

  @override
  List<Object?> get props => [resolution, quality, targetFps, port, lensDirection];
}
