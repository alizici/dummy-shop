import 'session_tokens.dart';

/// Where session tokens live between app starts.
///
/// Kept as an interface so the session logic stays pure Dart and testable;
/// the app wires in the platform's secure store (see
/// `lib/platform/secure_token_storage.dart`).
abstract interface class TokenStorage {
  Future<SessionTokens?> read();
  Future<void> write(SessionTokens tokens);
  Future<void> clear();
}

/// In-memory storage for tests and previews.
class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([this._tokens]);

  SessionTokens? _tokens;

  @override
  Future<SessionTokens?> read() async => _tokens;

  @override
  Future<void> write(SessionTokens tokens) async {
    _tokens = tokens;
  }

  @override
  Future<void> clear() async {
    _tokens = null;
  }
}
