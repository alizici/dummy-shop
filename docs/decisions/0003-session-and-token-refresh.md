# 0003 · Session and token refresh

**Status:** accepted · 2026-10-30

## Context

DummyJSON returns a JWT access token and a refresh token. `POST /auth/refresh` exchanges the refresh token; an
invalid one gets `403` (not `401`). `/auth/me` returns `401` for a missing or expired access token. The task asks to
store the token securely.

Typical bugs in this area: tokens in `SharedPreferences`; five parallel requests starting five refreshes; a user
signed out because the subway had no signal during a refresh; a refresh that goes through the auth interceptor and
loops.

## Decision

**Storage.** `flutter_secure_storage`: Keychain on iOS (`first_unlock_this_device`: readable after the first unlock,
never synced or restored to another device), encrypted storage on Android. `TokenStorage` is an interface, so the
session logic is plain Dart and tests use an in-memory store. `SessionTokens.toString()` never prints tokens.

**One owner.** `SessionManager` owns the tokens:

- `usable()` returns tokens that are safe to send; if the JWT's `exp` is within 60 seconds, it refreshes first.
  A token without a readable `exp` is left to the server.
- `refresh(stale)` is single-flight: callers holding the same stale token share one call; a caller whose token was
  already replaced gets the new one without a call.
- Only `RefreshRejected` ends the session. Any other failure (no network, 5xx) is rethrown and the user stays
  signed in.
- `end(reason)` clears storage and emits `SessionEnd.loggedOut` or `.expired` on `ended`.

**Two Dio clients.** `public` for login and refresh (no auth logic), `authorized` with `AuthInterceptor`:

- before a request: attach `usable()` tokens;
- after a `401` on a request that carried a token: refresh if that token is still the current one, then retry once
  (marked in `extra`, so a second `401` is final). The retry passes through `onRequest` again, which attaches the
  new token.

**Rejection is 400, 401 or 403 from `/auth/refresh`.** DummyJSON answers an invalid refresh token with `403`;
treating only `401` as rejection would turn an expired session into an endless "no connection" state. Other
statuses (408, 429, 5xx) are temporary and keep the session. Tests pin both sides.

**A refresh can't outlive its session.** If the user signs out, or someone else signs in, while a refresh is in
flight, its result is thrown away instead of being stored, and a late rejection doesn't end the new session.

**An unreadable token store means no session.** `SecureTokenStorage` treats a failing read (e.g. Android keys lost
after a backup restore) as no tokens, and `restore()` starts signed out instead of waiting on the splash screen.

**The app reacts in one place.** `SessionCubit` listens to `ended`; the router redirects on its state; the login
page shows "Your session expired" only for `expired`, not after a normal sign-out. Restoring on start uses
`GET /auth/me`, and a failed check (offline, 5xx) keeps the user signed in without a profile.

The refresh logic is locked by the code shield (`shield.json`, lock `session-refresh`): changing it needs an approved
reason and its tests to pass.

## Consequences

- Covered by `session_manager_test`, `auth_interceptor_test` (parallel 401s share one refresh, proactive refresh,
  rejected vs. offline refresh), `auth_flow_test` (the real wiring) and `app_flow_test` (expiry while browsing lands
  on the login page with the note).
- DummyJSON has no logout endpoint, so sign-out is local: tokens are cleared and the user's routes and blocs are
  disposed.
