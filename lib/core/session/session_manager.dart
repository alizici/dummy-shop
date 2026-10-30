import 'dart:async';

import 'session_end.dart';
import 'session_tokens.dart';
import 'token_storage.dart';

export 'session_end.dart';

/// Thrown by a [TokenRefresher] when the server refuses the refresh token.
/// Anything else a refresher throws is treated as temporary (network, 5xx).
class RefreshRejected implements Exception {
  const RefreshRejected([this.reason = 'refresh rejected']);

  final String reason;

  @override
  String toString() => 'RefreshRejected: $reason';
}

/// Exchanges a refresh token for new session tokens.
typedef TokenRefresher = Future<SessionTokens> Function(String refreshToken);

/// Owns the session tokens: loads them, refreshes them, ends the session.
///
/// Rules (docs/decisions/0003-session-and-token-refresh.md):
/// - Refresh is single-flight: callers that find the same token stale share
///   one refresh call; a caller whose token was already replaced gets the new
///   one without another call.
/// - Only a rejected refresh ends the session. A refresh that fails for any
///   other reason (no network, server error) is rethrown and the user stays
///   signed in.
/// - Ending a session clears storage and announces it on [ended], so the app
///   can drop everything that belonged to the user.
class SessionManager {
  SessionManager({
    required TokenStorage storage,
    required TokenRefresher refresher,
    DateTime Function()? clock,
    this.refreshMargin = const Duration(seconds: 60),
  }) : _storage = storage,
       _refresher = refresher,
       _clock = clock ?? DateTime.now;

  final TokenStorage _storage;
  final TokenRefresher _refresher;
  final DateTime Function() _clock;

  /// How long before expiry a token is refreshed proactively.
  final Duration refreshMargin;

  final _ended = StreamController<SessionEnd>.broadcast();
  SessionTokens? _tokens;
  bool _loaded = false;
  Future<SessionTokens>? _refreshing;

  /// Emits whenever a session ends.
  Stream<SessionEnd> get ended => _ended.stream;

  /// The current tokens, or null when signed out. Loads storage on first use.
  Future<SessionTokens?> current() async {
    if (!_loaded) {
      _tokens = await _storage.read();
      _loaded = true;
    }
    return _tokens;
  }

  /// Stores the tokens of a new session.
  Future<void> start(SessionTokens tokens) async {
    await _storage.write(tokens);
    _tokens = tokens;
    _loaded = true;
  }

  /// Tokens that are safe to send now, refreshed first if they're about to
  /// expire. Null when signed out.
  Future<SessionTokens?> usable() async {
    final tokens = await current();
    if (tokens == null || !tokens.expiresWithin(refreshMargin, _clock())) return tokens;
    return refresh(tokens);
  }

  /// Refreshes the session that [stale] belongs to, once for all callers.
  ///
  /// Throws [RefreshRejected] (after ending the session) when the server
  /// refuses or the session ended meanwhile, or rethrows the refresher's error
  /// when it failed temporarily.
  Future<SessionTokens> refresh(SessionTokens stale) async {
    final tokens = await current();
    if (tokens == null) throw const RefreshRejected('no session');
    if (tokens.accessToken != stale.accessToken) return tokens; // someone already refreshed
    return _refreshing ??= _refresh(tokens).whenComplete(() => _refreshing = null);
  }

  Future<SessionTokens> _refresh(SessionTokens tokens) async {
    final SessionTokens fresh;
    try {
      fresh = await _refresher(tokens.refreshToken);
    } on RefreshRejected {
      if (_tokens == tokens) await end(SessionEnd.expired);
      rethrow;
    }
    // The user signed out (or someone else signed in) while the refresh was
    // in flight: its result belongs to a session that no longer exists.
    if (_tokens != tokens) throw const RefreshRejected('the session changed during the refresh');
    await _storage.write(fresh);
    _tokens = fresh;
    return fresh;
  }

  /// Ends the session: clears the tokens and announces [reason].
  Future<void> end(SessionEnd reason) async {
    final hadSession = await current() != null;
    _tokens = null;
    await _storage.clear();
    if (hadSession || reason == SessionEnd.loggedOut) _ended.add(reason);
  }

  Future<void> dispose() => _ended.close();
}
