import 'package:dummy_shop/app/app.dart';
import 'package:dummy_shop/app/dependencies.dart';
import 'package:dummy_shop/core/session/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';
import 'support/samples.dart';

/// The whole app (router, blocs, real wiring) against a fake server.
void main() {
  const welcome = 'Welcome back';
  const expiredText = 'Your session expired. Please sign in again.';

  late FakeServer server;
  late InMemoryTokenStorage storage;

  final tokens = sessionTokens('emily');

  setUp(() {
    server = FakeServer()
      ..on('POST', '/auth/login', (request) {
        final body = request.data as Map<String, Object?>;
        return body['password'] == 'emilyspass'
            ? FakeReply(200, loginJson(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken))
            : const FakeReply(400, {'message': 'Invalid credentials'});
      })
      ..reply('GET', '/auth/me', 200, userJson())
      ..reply('GET', '/products', 200, {
        'products': [for (var i = 1; i <= 3; i++) sampleProductJson(i)],
        'total': 3,
        'skip': 0,
        'limit': 20,
      })
      ..reply('GET', '/products/1', 200, fixture('product_1.json'));
    storage = InMemoryTokenStorage();
  });

  Future<void> startApp(WidgetTester tester) async {
    await tester.pumpWidget(
      App(
        dependencies: AppDependencies.create(storage: storage, httpClientAdapter: server),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester, String password) async {
    await tester.enterText(find.byKey(const Key('login.username')), 'emilys');
    await tester.enterText(find.byKey(const Key('login.password')), password);
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('sign in, browse, open a product, sign out', (tester) async {
    await startApp(tester);
    expect(find.text(welcome), findsOneWidget);

    await signIn(tester, 'wrong');
    expect(find.text('Wrong username or password.'), findsOneWidget);

    await signIn(tester, 'emilyspass');
    expect(find.text('Product 1'), findsOneWidget);
    expect(find.text("You've seen all 3 products"), findsOneWidget);
    expect((await storage.read())?.accessToken, tokens.accessToken);

    await tester.tap(find.text('Product 1'));
    await tester.pumpAndSettle();
    expect(find.text('Essence Mascara Lash Princess'), findsOneWidget, reason: 'details replace the summary');
    expect(find.textContaining('The Essence Mascara Lash Princess is a popular mascara'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Product 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('products.logout')));
    await tester.pumpAndSettle();
    expect(find.text(welcome), findsOneWidget);
    expect(find.text(expiredText), findsNothing);
    expect(await storage.read(), isNull);
  });

  testWidgets('a stored session opens the catalog directly', (tester) async {
    await storage.write(tokens);
    await startApp(tester);

    expect(find.text('Product 1'), findsOneWidget);
    expect(server.calls('POST', '/auth/login'), isEmpty);
  });

  testWidgets('an expired stored session lands on sign-in with an explanation', (tester) async {
    await storage.write(tokens);
    server
      ..reply('GET', '/auth/me', 401, {'message': 'Token Expired!'})
      ..reply('POST', '/auth/refresh', 403, {'message': 'Invalid refresh token'});
    await startApp(tester);

    expect(find.text(welcome), findsOneWidget);
    expect(find.text(expiredText), findsOneWidget);
  });

  testWidgets('offline at start keeps the user signed in', (tester) async {
    await storage.write(tokens);
    server
      ..on('GET', '/auth/me', (_) => const FakeReply.offline())
      ..on('GET', '/products', (_) => const FakeReply.offline());
    await startApp(tester);

    expect(find.text("Couldn't load products"), findsOneWidget);
    expect(await storage.read(), tokens);
  });

  testWidgets('a session rejected while browsing sends the user to sign-in', (tester) async {
    await storage.write(tokens);
    server
      ..reply('GET', '/products', 401, {'message': 'Token Expired!'})
      ..reply('POST', '/auth/refresh', 403, {'message': 'Invalid refresh token'});
    await startApp(tester);

    expect(find.text(welcome), findsOneWidget);
    expect(find.text(expiredText), findsOneWidget);
    expect(await storage.read(), isNull);
  });
}
