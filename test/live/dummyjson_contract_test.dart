@Tags(['live'])
library;

import 'dart:io';

import 'package:dio/io.dart';
import 'package:dummy_shop/app/dependencies.dart';
import 'package:dummy_shop/core/network/api_failure.dart';
import 'package:dummy_shop/core/session/session_tokens.dart';
import 'package:dummy_shop/core/session/token_storage.dart';
import 'package:dummy_shop/features/auth/data/auth_repository.dart';
import 'package:dummy_shop/features/products/data/products_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Checks the real DummyJSON API against what the app expects. Skipped by
/// default (see dart_test.yaml); run with:
///
///     flutter test --run-skipped --tags live
///
/// Every other test uses saved responses. This one catches the API drifting
/// away from them.
void main() {
  late AppDependencies app;

  setUp(() => app = AppDependencies.create(storage: InMemoryTokenStorage(), httpClientAdapter: _adapter()));

  test('sign-in, session check and refresh', () async {
    final user = await app.auth.login(username: 'emilys', password: 'emilyspass');
    expect(user.username, 'emilys');

    final tokens = (await app.session.current())!;
    expect(tokens.accessExpiresAt, isNotNull, reason: 'the access token is a JWT with an exp claim');
    expect(await app.auth.restore(), isA<ActiveSession>());

    final refreshed = await app.session.refresh(tokens);
    expect(refreshed.accessExpiresAt, isNotNull);
    expect(await app.auth.restore(), isA<ActiveSession>(), reason: 'the refreshed token is accepted');
  });

  test('a wrong password is reported as such', () async {
    await expectLater(app.auth.login(username: 'emilys', password: 'nope'), throwsA(isA<InvalidCredentialsFailure>()));
  });

  test('a rejected session ends instead of looping', () async {
    await app.session.start(const SessionTokens(accessToken: 'bogus', refreshToken: 'bogus'));
    expect(await app.auth.restore(), isA<NoSession>());
    expect(await app.session.current(), isNull);
  });

  test('the whole catalog parses, page by page', () async {
    await app.auth.login(username: 'emilys', password: 'emilyspass');

    final first = await app.products.page();
    expect(first.items, hasLength(ProductsRepository.pageSize));

    final ids = <int>{};
    for (var skip = 0; skip < first.total; skip += 100) {
      final page = await app.products.page(skip: skip, limit: 100);
      ids.addAll(page.items.map((p) => p.id));
    }
    expect(ids, hasLength(first.total), reason: 'no product is lost or repeated across pages');
  });

  test('details parse, with and without a brand', () async {
    expect((await app.products.details(1)).summary.brand, isNotNull);
    expect((await app.products.details(17)).summary.brand, isNull); // groceries have none
    await expectLater(app.products.details(0), throwsA(isA<ServerFailure>()));
  });
}

/// Honors HTTPS_PROXY and SSL_CERT_FILE, for networks that need them.
IOHttpClientAdapter _adapter() => IOHttpClientAdapter(
  createHttpClient: () {
    final context = SecurityContext(withTrustedRoots: true);
    final certificates = Platform.environment['SSL_CERT_FILE'];
    if (certificates != null) context.setTrustedCertificates(certificates);
    return HttpClient(context: context)..findProxy = HttpClient.findProxyFromEnvironment;
  },
);
