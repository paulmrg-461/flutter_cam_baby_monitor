import 'package:baby_monitor/core/security/token_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('success: generates a URL-safe token of sufficient length', () {
    final token = TokenGenerator.generate();

    expect(token.length, greaterThanOrEqualTo(24));
    expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(token), isTrue);
  });

  test('failure: never returns an empty token', () {
    for (var i = 0; i < 20; i++) {
      expect(TokenGenerator.generate(), isNotEmpty);
    }
  });

  test('security: consecutive tokens are unique, not predictable/static', () {
    final tokens = List.generate(50, (_) => TokenGenerator.generate());

    expect(tokens.toSet().length, tokens.length);
  });
}
