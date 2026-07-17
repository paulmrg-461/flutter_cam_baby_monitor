import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_generator.dart';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'baby_monitor_stream_token';

  final FlutterSecureStorage _storage;

  Future<String> getOrCreateToken() async {
    final existing = await _storage.read(key: _key);
    if (existing != null && existing.isNotEmpty) return existing;
    return regenerateToken();
  }

  Future<String> regenerateToken() async {
    final token = TokenGenerator.generate();
    await _storage.write(key: _key, value: token);
    return token;
  }
}
