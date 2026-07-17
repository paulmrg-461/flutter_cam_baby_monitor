import 'dart:convert';
import 'dart:math';

class TokenGenerator {
  static const _length = 24;

  static String generate() {
    final random = Random.secure();
    final bytes = List<int>.generate(_length, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
