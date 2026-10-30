import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/session/session_tokens.dart';
import '../core/session/token_storage.dart';

/// [TokenStorage] on the platform's secure store: Keychain on iOS,
/// Keystore-backed storage on Android.
///
/// `first_unlock_this_device`: readable after the first unlock (so a refresh
/// can run in the background) and never restored to another device from a
/// backup.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([
    this._storage = const FlutterSecureStorage(
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
    ),
  ]);

  final FlutterSecureStorage _storage;

  static const _prefix = 'session.';
  static const _keys = ['accessToken', 'refreshToken', 'accessExpiresAt'];

  /// Tokens that can't be read (e.g. Android keys lost after a backup restore)
  /// are treated as no session: the user signs in again instead of being stuck.
  @override
  Future<SessionTokens?> read() async {
    try {
      final values = <String, String>{};
      for (final key in _keys) {
        final value = await _storage.read(key: '$_prefix$key');
        if (value != null) values[key] = value;
      }
      return SessionTokens.fromStorage(values);
    } on PlatformException {
      try {
        await _storage.deleteAll();
      } on PlatformException {
        // Nothing more to do: the next sign-in overwrites the keys anyway.
      }
      return null;
    }
  }

  @override
  Future<void> write(SessionTokens tokens) async {
    // Clear first so a token without expiry doesn't keep a stale one.
    await clear();
    for (final entry in tokens.toStorage().entries) {
      await _storage.write(key: '$_prefix${entry.key}', value: entry.value);
    }
  }

  @override
  Future<void> clear() async {
    for (final key in _keys) {
      await _storage.delete(key: '$_prefix$key');
    }
  }
}
