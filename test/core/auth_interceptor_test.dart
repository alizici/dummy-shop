import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dummy_shop/core/network/api_failure.dart';
import 'package:dummy_shop/core/network/auth_interceptor.dart';
import 'package:dummy_shop/core/session/session_manager.dart';
import 'package:dummy_shop/core/session/session_tokens.dart';
import 'package:dummy_shop/core/session/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_server.dart';

void main() {
  final now = DateTime.utc(2026, 10, 30, 12);

  SessionTokens tokens(String name, {Duration validFor = const Duration(minutes: 30)}) =>
      SessionTokens(accessToken: 'access-$name', refreshToken: 'refresh-$name', accessExpiresAt: now.add(validFor));

  final old = tokens('old');
  final fresh = tokens('fresh');

  late FakeServer server;
  late SessionManager session;
  late Dio dio;
  late int refreshes;
  late Future<SessionTokens> Function() onRefresh;

  setUp(() async {
    server = FakeServer();
    refreshes = 0;
    onRefresh = () async => fresh;
    session = SessionManager(
      storage: InMemoryTokenStorage(old),
      refresher: (_) {
        refreshes++;
        return onRefresh();
      },
      clock: () => now,
    );
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = server;
    dio.interceptors.add(AuthInterceptor(session: session, retryClient: dio));
  });

  tearDown(() => session.dispose());

  Future<Object?> get() => guardApi(() async => (await dio.get<Object?>('/data')).data);

  /// Accepts only the fresh token, like a server whose old token expired.
  void acceptOnly(SessionTokens accepted) => server.on(
    'GET',
    '/data',
    (r) => bearerOf(r) == 'Bearer ${accepted.accessToken}'
        ? const FakeReply(200, {'ok': true})
        : const FakeReply(401, {'message': 'Token Expired!'}),
  );

  List<String?> sentTokens() => server.requests.map(bearerOf).toList();

  test('sends the session token', () async {
    acceptOnly(old);
    expect(await get(), {'ok': true});
    expect(sentTokens(), ['Bearer ${old.accessToken}']);
  });

  test('sends no token when signed out', () async {
    await session.end(SessionEnd.loggedOut);
    server.reply('GET', '/data', 200, {'ok': true});

    await get();
    expect(sentTokens(), [null]);
  });

  test('a 401 refreshes once and retries once with the new token', () async {
    acceptOnly(fresh);

    expect(await get(), {'ok': true});
    expect(refreshes, 1);
    expect(sentTokens(), ['Bearer ${old.accessToken}', 'Bearer ${fresh.accessToken}']);
  });

  test('a second 401 is final', () async {
    server.reply('GET', '/data', 401, {'message': 'Invalid token'});

    await expectLater(get(), throwsA(isA<UnauthorizedFailure>()));
    expect(refreshes, 1);
    expect(server.requests, hasLength(2));
  });

  test('parallel requests that hit a 401 share one refresh', () async {
    acceptOnly(fresh);
    final gate = Completer<SessionTokens>();
    onRefresh = () => gate.future;

    final results = Future.wait([get(), get(), get()]);
    await settle();
    gate.complete(fresh);

    expect(await results, everyElement({'ok': true}));
    expect(refreshes, 1);
    expect(sentTokens().where((t) => t == 'Bearer ${fresh.accessToken}'), hasLength(3));
  });

  test('a token about to expire is refreshed before the request goes out', () async {
    session = SessionManager(
      storage: InMemoryTokenStorage(tokens('old', validFor: const Duration(seconds: 20))),
      refresher: (_) async {
        refreshes++;
        return fresh;
      },
      clock: () => now,
    );
    dio.interceptors
      ..clear()
      ..add(AuthInterceptor(session: session, retryClient: dio));
    acceptOnly(fresh);

    await get();
    expect(refreshes, 1);
    expect(sentTokens(), ['Bearer ${fresh.accessToken}']);
  });

  test('a rejected refresh ends the session', () async {
    acceptOnly(fresh);
    onRefresh = () => throw const RefreshRejected('HTTP 403');

    await expectLater(get(), throwsA(isA<UnauthorizedFailure>()));
    expect(await session.current(), isNull);
    expect(server.requests, hasLength(1));
  });

  test('a refresh that fails for lack of network keeps the user signed in', () async {
    acceptOnly(fresh);
    onRefresh = () => throw DioException.connectionError(requestOptions: RequestOptions(), reason: 'offline');

    await expectLater(get(), throwsA(isA<NetworkFailure>()));
    expect(await session.current(), old);
  });

  test('a 401 for a request sent without a token is not retried', () async {
    await session.end(SessionEnd.loggedOut);
    server.reply('GET', '/data', 401);

    await expectLater(get(), throwsA(isA<UnauthorizedFailure>()));
    expect(refreshes, 0);
    expect(server.requests, hasLength(1));
  });
}
