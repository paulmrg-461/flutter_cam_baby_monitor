import 'package:baby_monitor/features/stream_client/domain/repositories/stream_client_repository.dart';
import 'package:baby_monitor/features/stream_client/presentation/cubit/stream_client_cubit.dart';
import 'package:baby_monitor/features/stream_client/presentation/cubit/stream_client_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStreamClientRepository extends Mock implements StreamClientRepository {}

void main() {
  late MockStreamClientRepository repository;

  setUpAll(() {
    registerFallbackValue('http://example.com/stream');
  });

  setUp(() {
    repository = MockStreamClientRepository();
    when(() => repository.dispose()).thenReturn(null);
  });

  blocTest<StreamClientCubit, StreamClientState>(
    'success: connect emits connecting then connected',
    build: () {
      when(() => repository.connect(any())).thenAnswer((_) async {});
      return StreamClientCubit(repository: repository);
    },
    act: (cubit) => cubit.connect('http://192.168.1.1:8080/stream?token=abc'),
    expect: () => const [
      StreamClientState(status: StreamClientStatus.connecting),
      StreamClientState(status: StreamClientStatus.connected),
    ],
  );

  blocTest<StreamClientCubit, StreamClientState>(
    'failure: connect throws -> emits error with a mapped, user-facing message',
    build: () {
      when(() => repository.connect(any()))
          .thenThrow(Exception('SocketException: Connection refused'));
      return StreamClientCubit(repository: repository);
    },
    act: (cubit) => cubit.connect('http://unreachable-host/stream'),
    expect: () => [
      const StreamClientState(status: StreamClientStatus.connecting),
      predicate<StreamClientState>(
        (s) =>
            s.status == StreamClientStatus.error &&
            s.errorMessage!.contains('Verifica la IP'),
      ),
    ],
  );

  test(
    'security: closing the cubit disposes the repository so no HTTP client leaks',
    () async {
      final cubit = StreamClientCubit(repository: repository);

      await cubit.close();

      verify(() => repository.dispose()).called(1);
    },
  );
}
