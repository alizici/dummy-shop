import 'package:dummy_shop/core/session/session_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/samples.dart';

void main() {
  final now = DateTime.utc(2026, 10, 30, 12);

  group('jwtExpiry', () {
    test('reads the exp claim', () {
      expect(jwtExpiry(fakeJwt(expiresAt: now)), now);
    });

    test('is null for something that is not a JWT', () {
      expect(jwtExpiry('opaque-token'), isNull);
      expect(jwtExpiry('a.%%%.c'), isNull);
      expect(jwtExpiry('a.${'bm90IGpzb24'}.c'), isNull); // "not json"
    });
  });

  group('SessionTokens', () {
    test('fromTokens takes the expiry from the access token', () {
      final tokens = SessionTokens.fromTokens(
        accessToken: fakeJwt(expiresAt: now),
        refreshToken: 'r',
      );
      expect(tokens.accessExpiresAt, now);
    });

    test('expiresWithin looks ahead by the margin', () {
      final tokens = SessionTokens(accessToken: 'a', refreshToken: 'r', accessExpiresAt: now);
      const margin = Duration(seconds: 60);
      expect(tokens.expiresWithin(margin, now.subtract(const Duration(minutes: 5))), isFalse);
      expect(tokens.expiresWithin(margin, now.subtract(const Duration(seconds: 30))), isTrue);
      expect(tokens.expiresWithin(margin, now.add(const Duration(minutes: 5))), isTrue);
    });

    test('an unknown expiry is left to the server', () {
      const tokens = SessionTokens(accessToken: 'a', refreshToken: 'r');
      expect(tokens.expiresWithin(const Duration(days: 365), now), isFalse);
    });

    test('survives a round trip through storage', () {
      final tokens = SessionTokens(accessToken: 'a', refreshToken: 'r', accessExpiresAt: now);
      expect(SessionTokens.fromStorage(tokens.toStorage()), tokens);
      expect(SessionTokens.fromStorage({'accessToken': 'a'}), isNull);
    });

    test('never prints the tokens', () {
      final tokens = SessionTokens(accessToken: 'secret-access', refreshToken: 'secret-refresh', accessExpiresAt: now);
      expect(tokens.toString(), isNot(contains('secret')));
    });
  });
}
