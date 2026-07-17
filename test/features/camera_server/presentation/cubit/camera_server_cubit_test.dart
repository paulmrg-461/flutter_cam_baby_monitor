import 'package:baby_monitor/core/security/token_storage.dart';
import 'package:baby_monitor/features/camera_server/domain/entities/stream_config.dart';
import 'package:baby_monitor/features/camera_server/domain/repositories/camera_repository.dart';
import 'package:baby_monitor/features/camera_server/presentation/cubit/camera_server_cubit.dart';
import 'package:baby_monitor/features/camera_server/presentation/cubit/camera_server_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCameraRepository extends Mock implements CameraRepository {}

class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCameraRepository repository;
  late MockTokenStorage tokenStorage;

  setUpAll(() {
    registerFallbackValue(const StreamConfig());
  });

  setUp(() {
    repository = MockCameraRepository();
    tokenStorage = MockTokenStorage();
    when(() => repository.cameraController).thenReturn(null);
    when(() => repository.dispose()).thenAnswer((_) async {});
    when(
      () => tokenStorage.getOrCreateToken(),
    ).thenAnswer((_) async => 'stable-token-123');
    when(
      () => tokenStorage.regenerateToken(),
    ).thenAnswer((_) async => 'new-token-456');
  });

  blocTest<CameraServerCubit, CameraServerState>(
    'success: initialize emits initializing then initialized with a tokened stream URL',
    build: () {
      when(() => repository.initialize(any())).thenAnswer((_) async {});
      return CameraServerCubit(repository: repository, tokenStorage: tokenStorage);
    },
    act: (cubit) => cubit.initialize(),
    expect: () => [
      predicate<CameraServerState>(
        (s) => s.status == CameraServerStatus.initializing,
      ),
      predicate<CameraServerState>(
        (s) =>
            s.status == CameraServerStatus.initialized &&
            s.streamUrl != null &&
            s.streamUrl!.contains('/stream?token=stable-token-123') &&
            s.browserUrl != null &&
            s.browserUrl!.contains('/?token=stable-token-123') &&
            s.config.authToken == 'stable-token-123',
      ),
    ],
  );

  blocTest<CameraServerCubit, CameraServerState>(
    'failure: repository throws -> emits error with a mapped, user-facing message',
    build: () {
      when(() => repository.initialize(any()))
          .thenThrow(Exception('CameraAccessException'));
      return CameraServerCubit(repository: repository, tokenStorage: tokenStorage);
    },
    act: (cubit) => cubit.initialize(),
    expect: () => [
      predicate<CameraServerState>(
        (s) => s.status == CameraServerStatus.initializing,
      ),
      predicate<CameraServerState>(
        (s) =>
            s.status == CameraServerStatus.error &&
            s.errorMessage ==
                'No se pudo acceder a la camara. Verifica los permisos.',
      ),
    ],
  );

  test(
    'security: reuses the persisted token across initialize() calls instead of minting a new one each time',
    () async {
      when(() => repository.initialize(any())).thenAnswer((_) async {});
      final cubit = CameraServerCubit(repository: repository, tokenStorage: tokenStorage);

      await cubit.initialize();
      await cubit.initialize();

      final captured =
          verify(() => repository.initialize(captureAny())).captured;
      final tokens =
          captured.cast<StreamConfig>().map((c) => c.authToken).toSet();

      expect(tokens, {'stable-token-123'});
      verify(() => tokenStorage.getOrCreateToken()).called(2);

      await cubit.close();
    },
  );

  test(
    'security: regenerateToken() disposes the active session and re-initializes with a fresh token',
    () async {
      when(() => repository.initialize(any())).thenAnswer((_) async {});
      final cubit = CameraServerCubit(repository: repository, tokenStorage: tokenStorage);
      await cubit.initialize();

      await cubit.regenerateToken();

      verify(() => repository.dispose()).called(1);
      expect(cubit.state.config.authToken, 'new-token-456');
      expect(cubit.state.streamUrl, contains('token=new-token-456'));

      await cubit.close();
    },
  );

  test(
    'security: regenerateToken() is a no-op before the server has ever been initialized',
    () async {
      final cubit = CameraServerCubit(repository: repository, tokenStorage: tokenStorage);

      await cubit.regenerateToken();

      verifyNever(() => repository.dispose());
      verifyNever(() => tokenStorage.regenerateToken());

      await cubit.close();
    },
  );
}
