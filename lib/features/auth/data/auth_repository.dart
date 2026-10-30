import 'dart:async';

import '../../../core/network/api_failure.dart';
import '../../../core/session/session_manager.dart';
import 'auth_api.dart';
import 'auth_user.dart';

/// What the app learns about the session when it starts.
sealed class RestoredSession {
  const RestoredSession();
}

/// No stored session, or the stored one was rejected.
final class NoSession extends RestoredSession {
  const NoSession();
}

/// A valid session; the user profile was loaded.
final class ActiveSession extends RestoredSession {
  const ActiveSession(this.user);
  final AuthUser user;
}

/// A stored session exists but couldn't be checked right now (no network,
/// server error). The user stays signed in: a failed check is not a reason
/// to log anyone out.
final class UnverifiedSession extends RestoredSession {
  const UnverifiedSession();
}

/// Sign-in, session restore and sign-out.
class AuthRepository {
  AuthRepository({required AuthApi api, required SessionManager session}) : _api = api, _session = session;

  final AuthApi _api;
  final SessionManager _session;

  /// Emits when the session ends: on logout, or when the server rejects it.
  Stream<SessionEnd> get sessionEnded => _session.ended;

  /// Throws [InvalidCredentialsFailure] for a wrong username or password,
  /// or another [ApiFailure].
  Future<AuthUser> login({required String username, required String password}) => guardApi(() async {
    final (user, tokens) = await _api.login(username: username.trim(), password: password);
    await _session.start(tokens);
    return user;
  });

  Future<RestoredSession> restore() async {
    try {
      if (await _session.current() == null) return const NoSession();
    } on Exception {
      // The token store couldn't be read. Start signed out rather than wait
      // on the splash screen forever.
      return const NoSession();
    }
    try {
      return ActiveSession(await guardApi(_api.me));
    } on UnauthorizedFailure {
      // The interceptor already tried a refresh. Make sure nothing is left.
      await _session.end(SessionEnd.expired);
      return const NoSession();
    } on ApiFailure {
      return const UnverifiedSession();
    }
  }

  Future<void> logout() => _session.end(SessionEnd.loggedOut);
}
