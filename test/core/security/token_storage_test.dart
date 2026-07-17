import 'package:baby_monitor/core/security/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockFlutterSecureStorage secureStorage;
  late TokenStorage tokenStorage;

  setUpAll(() {
    registerFallbackValue('fallback-key');
  });

  setUp(() {
    secureStorage = MockFlutterSecureStorage();
    tokenStorage = TokenStorage(storage: secureStorage);
  });

  test('success: returns the already-persisted token without writing again', () async {
    when(
      () => secureStorage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => 'existing-token');

    final token = await tokenStorage.getOrCreateToken();

    expect(token, 'existing-token');
    verifyNever(
      () => secureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    );
  });

  test('failure: generates and persists a new token when none exists yet', () async {
    when(
      () => secureStorage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    when(
      () => secureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});

    final token = await tokenStorage.getOrCreateToken();

    expect(token, isNotEmpty);
    verify(
      () => secureStorage.write(key: any(named: 'key'), value: token),
    ).called(1);
  });

  test('security: regenerateToken() always mints and persists a fresh, different token', () async {
    when(
      () => secureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});

    final first = await tokenStorage.regenerateToken();
    final second = await tokenStorage.regenerateToken();

    expect(first, isNot(equals(second)));
  });
}
