# Dummy Shop

A small Flutter app against [DummyJSON](https://dummyjson.com): sign in, browse products with pagination, open a product.
Built as a test task, with the structure I'd use for a real client app: BLoC, a strict API layer, a session that
survives bad networks, and tests that prove each of those.

| Sign in | Products | Detail |
|---|---|---|
| `emilys` / `emilyspass` (one-tap test account button), validation, wrong-password and offline messages, "session expired" note | first-load loader, error with retry, empty state, pull to refresh, infinite scroll with prefetch, retry under the list, sign out | shows what the list already knew instantly, loads the rest (gallery, description, shipping, tags, reviews), inline retry |

## Run

```bash
flutter pub get
flutter run            # iOS or Android
flutter test           # 150 tests, ~25 s
flutter analyze
```

Built and tested with Flutter 3.47.9 (Dart 3.13).

## Decisions

Short versions; each one links to a one-page decision record with the alternatives I weighed.

- **BLoC, in layers, with the rules checked by a test.** `data` → `bloc` → `presentation` per feature, plain-Dart
  `core` underneath, one composition root on top. Blocs never see Dio; screens never see the API.
  `test/architecture_test.dart` fails the build if an import breaks a rule. → [ADR 0001](docs/decisions/0001-bloc-and-layers.md)
- **A strict JSON reader instead of code generation.** For two endpoints, generated models add a build step for little
  gain. The reader never invents defaults: a missing price is an error that names `$.products[3].price`, not a `0`
  on screen. (With a real OpenAPI spec I'd generate the client.) → [ADR 0002](docs/decisions/0002-strict-json-reader.md)
- **A session that only ends when the server says so.** Tokens live in the Keychain/Keystore. Expiring tokens are
  refreshed before the request; a 401 refreshes once and retries once; parallel requests share one refresh. No
  network during refresh or start-up keeps you signed in; only a rejected refresh token (400/401/403) signs you
  out, with a message. A refresh that finishes after sign-out is thrown away. → [ADR 0003](docs/decisions/0003-session-and-token-refresh.md)
- **The product list handles its events one at a time.** Pull to refresh and "next page" can't race, so a slow page
  never lands on a freshly refreshed list. Paging follows the server offset, not the list length, so duplicate
  requests and pages with nothing new can't loop. → [ADR 0004](docs/decisions/0004-product-list.md)

The whole picture, with diagrams: [docs/architecture.md](docs/architecture.md).

## Structure

```
lib/
  core/        plain Dart, no Flutter: JsonReader, ApiFailure, SessionManager, AuthInterceptor
  platform/    the only code that touches the device: SecureTokenStorage
  features/
    auth/      data (AuthApi, AuthRepository) · bloc (SessionCubit, LoginCubit) · presentation
    products/  data (ProductsRepository, models) · bloc (ProductsBloc, ProductDetailCubit) · presentation
  app/         composition root (dependencies.dart), router, theme, failure messages
test/          mirrors lib/, plus app_flow_test, architecture_test, fixtures and a live contract test
```

## Tests

| Kind | What it proves |
|---|---|
| Unit (`test/core`) | JSON paths in errors; single-flight refresh; a network failure never signs anyone out; 401 → refresh → one retry |
| Wiring (`auth_flow_test`, `products_repository_test`) | the real `AppDependencies` (both Dio clients, interceptor, session) against a fake server |
| Bloc (`bloc_test`) | every list state, pagination edges, dedupe, refresh vs. next page ordering |
| Widget | each screen state, prefetch, retry, pull to refresh waiting for the bloc |
| Small screens | list tile and detail page at 320 and 360 dp with text scaled up to 1.5×: they wrap, never overflow |
| App flow | the whole app: sign in → list → detail → back → sign out; restore; expiry while browsing |
| Architecture | the layer rules above, plus checks that the checker itself catches violations |
| Live contract | `flutter test --run-skipped --tags live`: the real API still matches (login, refresh, all 194 products parse) |

Fixtures in `test/fixtures` are real DummyJSON responses (`tool/refresh_fixtures.sh` re-downloads them).

To check that the tests catch real bugs, I broke the code on purpose in 17 places: dropped the single-flight
refresh, let a refresh finish after sign-out, removed the sequential event handling, paged by list length instead of
server offset, treated DummyJSON's `403` refresh rejection as a network error, and so on. Every one was caught by a
failing test. Recording the demo found one more (a page landing mid-drag requested the next page early); it
now has its own test and a different trigger.

## Working with AI

I use Claude Code daily, inside guardrails I built for it
([claude-code-guardrails](https://github.com/alizici/claude-code-guardrails)). The setup is included but switched
off, so opening the repo runs nothing: `CLAUDE.md` holds the project rules, `.claude/agents/` has role agents that keep
test writing and implementation apart, and `.claude/settings.example.json` wires hooks that run `analyze`, `format`
and the tests before a turn can end and lock the session code (`shield.json`). The decisions and the review are mine.

## Assumptions and next steps

Assumptions I made where the task left room are in [docs/OPEN_QUESTIONS.md](docs/OPEN_QUESTIONS.md).

With more time I'd add: image caching, search, an offline cache for the last page, localization, golden tests,
and CI running the same gates.
