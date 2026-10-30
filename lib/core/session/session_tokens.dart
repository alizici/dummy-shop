import 'dart:convert';

import 'package:equatable/equatable.dart';

/// The tokens of one signed-in session.
class SessionTokens extends Equatable {
  const SessionTokens({required this.accessToken, required this.refreshToken, this.accessExpiresAt});

  final String accessToken;
  final String refreshToken;

  /// When [accessToken] expires, read from its JWT `exp` claim when present.
  final DateTime? accessExpiresAt;

  /// Builds tokens and reads the access token's expiry from the token itself.
  factory SessionTokens.fromTokens({required String accessToken, required String refreshToken}) =>
      SessionTokens(accessToken: accessToken, refreshToken: refreshToken, accessExpiresAt: jwtExpiry(accessToken));

  /// Whether the access token is expired, or will be within [margin] of [now].
  /// Unknown expiry counts as valid: the server decides, and a 401 triggers
  /// a refresh anyway.
  bool expiresWithin(Duration margin, DateTime now) {
    final expiresAt = accessExpiresAt;
    return expiresAt != null && !now.add(margin).isBefore(expiresAt);
  }

  Map<String, String> toStorage() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    if (accessExpiresAt != null) 'accessExpiresAt': accessExpiresAt!.toUtc().toIso8601String(),
  };

  static SessionTokens? fromStorage(Map<String, String> values) {
    final access = values['accessToken'];
    final refresh = values['refreshToken'];
    if (access == null || refresh == null) return null;
    final expires = values['accessExpiresAt'];
    return SessionTokens(
      accessToken: access,
      refreshToken: refresh,
      accessExpiresAt: expires == null ? null : DateTime.tryParse(expires),
    );
  }

  @override
  List<Object?> get props => [accessToken, refreshToken, accessExpiresAt];

  /// Never print tokens: logs and crash reports end up in too many places.
  @override
  String toString() => 'SessionTokens(expires: $accessExpiresAt)';
}

/// The `exp` claim of a JWT as a UTC time, or null if [token] isn't a JWT
/// with a numeric `exp`. The signature isn't checked; that's the server's job.
DateTime? jwtExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    if (payload is Map<String, Object?>) {
      final exp = payload['exp'];
      if (exp is num) return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
    }
  } on FormatException {
    return null;
  }
  return null;
}
