import 'dart:async';

import 'package:dummy_shop/core/network/api_failure.dart';
import 'package:dummy_shop/core/session/session_manager.dart';
import 'package:dummy_shop/core/session/session_tokens.dart';
import 'package:dummy_shop/core/session/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 30, 12);

  SessionTokens tokens(String name, {Duration validFor = const Duration(minutes: 30)}) =>
      SessionTokens(accessToken: 'access-$name', refreshToken: 'refresh-$name', accessExpiresAt: now.add(validFor));

  final old = tokens('old');
  final fresh = tokens('fresh');

  late InMemoryTokenStorage storage;
  late List<String> refreshCalls;
  late Future<SessionTokens> Function() onRefresh;
  late SessionManager session;
  late List<SessionEnd> ended;

  setUp(() {
    storage = InMemoryTokenStorage(old);
    refreshCalls = [];
    onRefresh = () async => fresh;
    session = SessionManager(
      storage: storage,
      refresher: (refreshToken) {
        refreshCalls.add(refreshToken);
        return onRefresh();
      },
      clock: () => now,
    );
    ended = [];
    session.ended.listen(ended.add);
  });

  tearDown(() => session.dispose());

  test('loads the stored session', () async {
    expect(await session.current(), old);
  });

  test('hands out valid tokens as they are', () async {
    expect(await session.usable(), old);
    expect(refreshCalls, isEmpty);
  });

  test('refreshes a token that is about to expire before handing it out', () async {
    await storage.write(tokens('old', validFor: const Duration(seconds: 30)));

    expect(await session.usable(), fresh);
    expect(refreshCalls, ['refresh-old']);
    expect(await storage.read(), fresh);
  });

  test('callers that find the same token stale share one refresh', () async {
    final gate = Completer<SessionTokens>();
    onRefresh = () => gate.future;

    final results = Future.wait([session.refresh(old), session.refresh(old), session.refresh(old)]);
    await Future<void>.delayed(Duration.zero);
    gate.complete(fresh);

    expect(await results, [fresh, fresh, fresh]);
    expect(refreshCalls, hasLength(1));
  });

  test('a caller whose token was already replaced gets the new one without a call', () async {
    await session.refresh(old);
    expect(await session.refresh(old), fresh);
    expect(refreshCalls, hasLength(1));
  });

  test('a rejected refresh ends the session', () async {
    onRefresh = () => throw const RefreshRejected('HTTP 403');

    await expectLater(session.refresh(old), throwsA(isA<RefreshRejected>()));
    expect(await session.current(), isNull);
    expect(await storage.read(), isNull);
    expect(ended, [SessionEnd.expired]);
  });

  test('a refresh that fails for another reason keeps the user signed in', () async {
    onRefresh = () => throw const NetworkFailure('offline');

    await expectLater(session.refresh(old), throwsA(isA<NetworkFailure>()));
    expect(await session.current(), old);
    expect(await storage.read(), old);
    expect(ended, isEmpty);

    // And the next attempt really tries again.
    onRefresh = () async => fresh;
    expect(await session.refresh(old), fresh);
    expect(refreshCalls, hasLength(2));
  });

  test('signing out during a refresh does not bring the session back', () async {
    final gate = Completer<SessionTokens>();
    onRefresh = () => gate.future;

    final refreshing = session.refresh(old);
    await Future<void>.delayed(Duration.zero);
    await session.end(SessionEnd.loggedOut);
    gate.complete(fresh);

    await expectLater(refreshing, throwsA(isA<RefreshRejected>()));
    expect(await session.current(), isNull);
    expect(await storage.read(), isNull);
  });

  test('a refresh for an old session does not touch a new sign-in', () async {
    final gate = Completer<SessionTokens>();
    onRefresh = () => gate.future;
    final bob = tokens('bob');

    final refreshing = session.refresh(old);
    await Future<void>.delayed(Duration.zero);
    await session.end(SessionEnd.loggedOut);
    await session.start(bob);
    gate.complete(fresh);

    await expectLater(refreshing, throwsA(isA<RefreshRejected>()));
    expect(await session.current(), bob);
    expect(await storage.read(), bob);
  });

  test('a late rejection for an old session does not end the new one', () async {
    final gate = Completer<SessionTokens>();
    onRefresh = () => gate.future;
    final bob = tokens('bob');

    final refreshing = session.refresh(old);
    await Future<void>.delayed(Duration.zero);
    await session.start(bob);
    gate.completeError(const RefreshRejected('HTTP 403'));

    await expectLater(refreshing, throwsA(isA<RefreshRejected>()));
    await Future<void>.delayed(Duration.zero);
    expect(await session.current(), bob);
    expect(ended, isEmpty);
  });

  test('refreshing without a session is rejected', () async {
    await storage.clear();
    await expectLater(session.refresh(old), throwsA(isA<RefreshRejected>()));
    expect(refreshCalls, isEmpty);
  });

  test('logging out clears the tokens and says so', () async {
    await session.end(SessionEnd.loggedOut);
    await Future<void>.delayed(Duration.zero);

    expect(await session.current(), isNull);
    expect(await storage.read(), isNull);
    expect(ended, [SessionEnd.loggedOut]);
  });

  test('ending a session that is already gone is not announced as an expiry', () async {
    await session.end(SessionEnd.expired);
    await session.end(SessionEnd.expired);
    await Future<void>.delayed(Duration.zero);

    expect(ended, [SessionEnd.expired]);
  });
}
