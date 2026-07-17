import 'package:camera/camera.dart';
import 'package:get_it/get_it.dart';

import '../../features/camera_server/data/datasources/audio_datasource.dart';
import '../../features/camera_server/data/datasources/camera_datasource.dart';
import '../../features/camera_server/data/datasources/mjpeg_server.dart';
import '../../features/camera_server/data/datasources/native_camera_datasource.dart';
import '../../features/camera_server/data/repositories/camera_repository_impl.dart';
import '../../features/camera_server/domain/repositories/camera_repository.dart';
import '../../features/stream_client/data/datasources/audio_client_datasource.dart';
import '../../features/stream_client/data/datasources/mjpeg_datasource.dart';
import '../../features/stream_client/data/datasources/motion_events_datasource.dart';
import '../../features/stream_client/data/repositories/stream_client_repository_impl.dart';
import '../../features/stream_client/data/services/pcm_audio_player.dart';
import '../../features/stream_client/domain/repositories/stream_client_repository.dart';
import '../security/token_storage.dart';

final sl = GetIt.instance;

class ServiceLocator {
  static List<CameraDescription> _cameras = [];
  static List<CameraDescription> get cameras => _cameras;

  static Future<void> initialize() async {
    _cameras = await availableCameras();
    _registerCameraServer();
    _registerStreamClient();
  }

  static void _registerCameraServer() {
    sl.registerLazySingleton(CameraDatasource.new);
    sl.registerLazySingleton(MjpegServer.new);
    sl.registerLazySingleton(NativeCameraDatasource.new);
    sl.registerLazySingleton(AudioDatasource.new);
    sl.registerLazySingleton(TokenStorage.new);
    sl.registerLazySingleton<CameraRepository>(
      () => CameraRepositoryImpl(
        cameraDatasource: sl<CameraDatasource>(),
        mjpegServer: sl<MjpegServer>(),
        nativeCameraDatasource: sl<NativeCameraDatasource>(),
        audioDatasource: sl<AudioDatasource>(),
      ),
    );
  }

  static void _registerStreamClient() {
    sl.registerLazySingleton(MjpegClientDatasource.new);
    sl.registerLazySingleton(MotionEventsDatasource.new);
    sl.registerLazySingleton(AudioClientDatasource.new);
    sl.registerLazySingleton(PcmAudioPlayer.new);
    sl.registerLazySingleton<StreamClientRepository>(
      () => StreamClientRepositoryImpl(
        datasource: sl(),
        motionDatasource: sl(),
        audioDatasource: sl(),
        audioPlayer: sl(),
      ),
    );
  }
}
