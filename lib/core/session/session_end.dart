/// Why a session ended.
enum SessionEnd {
  /// The user signed out.
  loggedOut,

  /// The refresh token was rejected or expired; the user has to sign in again.
  expired,
}
