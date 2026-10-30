# Open questions and assumptions

Where the task left room, I made a call and wrote it down here. In a client project each of these would be a short
question to the client before or during the work.

| # | Question | Assumption made | Where |
|---|---|---|---|
| 1 | The task says `GET /products`; DummyJSON also has `/auth/products`, which requires the token. Which one? | `GET /products`, as written. It goes through the authorized client anyway, so switching is a one-line path change. | `products_repository.dart` |
| 2 | How long should a session last? | Access token asked for 30 minutes (`expiresInMins`), refreshed 60 s before expiry and after a 401. | `auth_api.dart`, `session_manager.dart` |
| 3 | Page size? | 20, with prefetch 600 px before the end. | `products_repository.dart`, `products_page.dart` |
| 4 | Sign-out on the server? | DummyJSON has no logout endpoint; sign-out clears the tokens locally and disposes the user's screens. | `auth_repository.dart` |
| 5 | What should the app do when it starts offline with a stored session? | Stay signed in and show the list's error state, instead of signing the user out. | `auth_repository.dart` (`UnverifiedSession`) |
| 6 | Platforms? | iOS and Android. Web would need a different answer for "store the token securely" (no Keychain in a browser). | `ios/`, `android/` |
| 7 | Language? | English UI strings, kept in the presentation layer (one place for failure messages). Localization is a next step. | `presentation/`, `app/failure_message.dart` |
| 8 | Deep links? | Not configured (no URL scheme or intent filter). The router already handles `/products/<id>` and a malformed id; a cold-start link would also need the target kept through the splash redirect. | `app/router.dart` |
