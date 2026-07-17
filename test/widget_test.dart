import 'package:baby_monitor/app.dart';
import 'package:baby_monitor/core/di/injection.dart';
import 'package:baby_monitor/core/security/token_storage.dart';
import 'package:baby_monitor/features/camera_server/domain/repositories/camera_repository.dart';
import 'package:baby_monitor/features/stream_client/domain/repositories/stream_client_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _FakeCameraRepository extends Mock implements CameraRepository {}

class _FakeStreamClientRepository extends Mock
    implements StreamClientRepository {}

class _FakeTokenStorage extends Mock implements TokenStorage {}

void main() {
  setUp(() {
    final cameraRepository = _FakeCameraRepository();
    when(() => cameraRepository.dispose()).thenAnswer((_) async {});
    sl.registerLazySingleton<CameraRepository>(() => cameraRepository);

    final streamClientRepository = _FakeStreamClientRepository();
    when(() => streamClientRepository.dispose()).thenReturn(null);
    sl.registerLazySingleton<StreamClientRepository>(
      () => streamClientRepository,
    );

    sl.registerLazySingleton<TokenStorage>(_FakeTokenStorage.new);
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('App renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const BabyMonitorApp());
    await tester.pump();

    expect(find.text('Baby Monitor - Servidor'), findsOneWidget);
    expect(find.text('Baby Monitor - Cliente'), findsNothing);
  });
}
