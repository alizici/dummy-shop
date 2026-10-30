import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/session/session_end.dart';
import '../data/auth_repository.dart';
import '../data/auth_user.dart';

enum SessionStatus { unknown, authenticated, unauthenticated }

class SessionState extends Equatable {
  const SessionState._(this.status, [this.user, this.endReason]);

  const SessionState.unknown() : this._(SessionStatus.unknown);

  /// [user] is null when the session was restored but couldn't be verified
  /// (e.g. offline).
  const SessionState.authenticated([AuthUser? user]) : this._(SessionStatus.authenticated, user);

  const SessionState.unauthenticated([SessionEnd? reason]) : this._(SessionStatus.unauthenticated, null, reason);

  final SessionStatus status;
  final AuthUser? user;

  /// Why the previous session ended, when it did (e.g. to explain an expiry).
  final SessionEnd? endReason;

  @override
  List<Object?> get props => [status, user, endReason];
}

/// App-wide session state. The router redirects on it, and the screens that
/// belong to a user live only while it is [SessionStatus.authenticated].
class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._auth) : super(const SessionState.unknown()) {
    _ended = _auth.sessionEnded.listen((reason) => emit(SessionState.unauthenticated(reason)));
  }

  final AuthRepository _auth;
  late final StreamSubscription<SessionEnd> _ended;

  Future<void> restore() async {
    final restored = await _auth.restore();
    emit(switch (restored) {
      ActiveSession(:final user) => SessionState.authenticated(user),
      UnverifiedSession() => const SessionState.authenticated(),
      // Already unauthenticated: the stored session was rejected during the
      // check and [sessionEnded] said why. Keep the reason for the login page.
      NoSession() when state.status == SessionStatus.unauthenticated => state,
      NoSession() => const SessionState.unauthenticated(),
    });
  }

  void signedIn(AuthUser user) => emit(SessionState.authenticated(user));

  Future<void> logout() => _auth.logout();

  @override
  Future<void> close() async {
    await _ended.cancel();
    return super.close();
  }
}
