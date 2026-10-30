import 'package:dummy_shop/app/dependencies.dart';
import 'package:dummy_shop/core/network/api_failure.dart';
import 'package:dummy_shop/core/session/session_manager.dart';
import 'package:dummy_shop/core/session/session_tokens.dart';
import 'package:dummy_shop/core/session/token_storage.dart';
import 'package:dummy_shop/features/auth/data/auth_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_server.dart';
import '../../support/samples.dart';

/// Sign-in, restore and sign-out through the app's real wiring
/// (AppDependencies, both Dio clients, the interceptor, the session manager),
/// with only the network replaced.
void main() {
  late FakeServer server;
  late InMemoryTokenStorage storage;
  late AuthRepository auth;
  late List<SessionEnd> ended;

  final old = sessionTokens('old');
  final fresh = sessionTokens('fresh');

  setUp(() {
    server = FakeServer();
    storage = InMemoryTokenStorage();
    auth = AppDependencies.create(storage: storage, httpClientAdapter: server).auth;
    ended = [];
    auth.sessionEnded.listen(ended.add);
  });

  group('login', () {
    test('stores the session and returns the user', () async {
      server.reply('POST', '/auth/login', 200, loginJson(accessToken: old.accessToken, refreshToken: old.refreshToken));

      final user = await auth.login(username: ' emilys ', password: 'emilyspass');

      expect(user, emily);
      expect(server.requests.single.data, {'username': 'emilys', 'password': 'emilyspass', 'expiresInMins': 30});
      expect(bearerOf(server.requests.single), isNull, reason: 'login goes out without a token');
      expect((await storage.read())?.accessToken, old.accessToken);
      expect((await storage.read())?.accessExpiresAt, old.accessExpiresAt);
    });

    test('wrong credentials are reported as such and store nothing', () async {
      server.reply('POST', '/auth/login', 400, {'message': 'Invalid credentials'});

      await expectLater(auth.login(username: 'emilys', password: 'nope'), throwsA(isA<InvalidCredentialsFailure>()));
      expect(await storage.read(), isNull);
    });

    test('no connection is a network failure, not a wrong password', () async {
      server.on('POST', '/auth/login', (_) => const FakeReply.offline());

      await expectLater(auth.login(username: 'emilys', password: 'emilyspass'), throwsA(isA<NetworkFailure>()));
    });

    test('a login response without tokens is an invalid response', () async {
      server.reply('POST', '/auth/login', 200, userJson());

      await expectLater(auth.login(username: 'emilys', password: 'emilyspass'), throwsA(isA<InvalidResponseFailure>()));
      expect(await storage.read(), isNull);
    });
  });

  group('restore', () {
    test('without a stored session there is nothing to check', () async {
      expect(await auth.restore(), isA<NoSession>());
      expect(server.requests, isEmpty);
    });

    test('a valid stored session loads the user', () async {
      await storage.write(old);
      server.reply('GET', '/auth/me', 200, userJson());

      expect(await auth.restore(), isA<ActiveSession>().having((s) => s.user, 'user', emily));
      expect(bearerOf(server.requests.single), 'Bearer ${old.accessToken}');
    });

    test('an expired access token is refreshed and the check retried', () async {
      await storage.write(old);
      server
        ..on(
          'GET',
          '/auth/me',
          (r) => bearerOf(r) == 'Bearer ${fresh.accessToken}' ? FakeReply(200, userJson()) : const FakeReply(401),
        )
        ..reply('POST', '/auth/refresh', 200, {'accessToken': fresh.accessToken, 'refreshToken': fresh.refreshToken});

      expect(await auth.restore(), isA<ActiveSession>());
      expect(server.calls('POST', '/auth/refresh').single.data, {
        'refreshToken': old.refreshToken,
        'expiresInMins': 30,
      });
      expect(bearerOf(server.calls('POST', '/auth/refresh').single), isNull, reason: 'refresh never carries a token');
      expect((await storage.read())?.accessToken, fresh.accessToken);
    });

    test('a rejected refresh token ends the session as expired', () async {
      await storage.write(old);
      server
        ..reply('GET', '/auth/me', 401, {'message': 'Token Expired!'})
        ..reply('POST', '/auth/refresh', 403, {'message': 'Invalid refresh token'});

      expect(await auth.restore(), isA<NoSession>());
      await settle();
      expect(await storage.read(), isNull);
      expect(ended, [SessionEnd.expired]);
    });

    test('no connection keeps the user signed in, unverified', () async {
      await storage.write(old);
      server.on('GET', '/auth/me', (_) => const FakeReply.offline());

      expect(await auth.restore(), isA<UnverifiedSession>());
      expect(await storage.read(), old);
      expect(ended, isEmpty);
    });

    test('a refresh refused for a temporary reason (429) keeps the session', () async {
      await storage.write(old);
      server
        ..reply('GET', '/auth/me', 401, {'message': 'Token Expired!'})
        ..reply('POST', '/auth/refresh', 429, {'message': 'Too many requests'});

      expect(await auth.restore(), isA<UnverifiedSession>());
      expect(await storage.read(), old);
      expect(ended, isEmpty);
    });

    test('an unreadable token store starts signed out instead of hanging', () async {
      final broken = AppDependencies.create(storage: _UnreadableStorage(), httpClientAdapter: server).auth;
      expect(await broken.restore(), isA<NoSession>());
    });

    test('a server error during the check does not sign the user out either', () async {
      await storage.write(old);
      server.reply('GET', '/auth/me', 503);

      expect(await auth.restore(), isA<UnverifiedSession>());
      expect(await storage.read(), old);
    });
  });

  test('logout clears the session and announces it', () async {
    await storage.write(old);

    await auth.logout();
    await settle();

    expect(await storage.read(), isNull);
    expect(ended, [SessionEnd.loggedOut]);
  });
}

/// Like a Keychain whose keys were lost: every read fails.
class _UnreadableStorage implements TokenStorage {
  @override
  Future<SessionTokens?> read() => throw PlatformException(code: 'read', message: 'BadPaddingException');

  @override
  Future<void> write(SessionTokens tokens) async {}

  @override
  Future<void> clear() async {}
}
