# 0001 · BLoC, in layers, with the rules checked by a test

**Status:** accepted · 2026-10-30

## Context

The task leaves state management and structure open. The app is small, but it's a sample of how I'd structure a
client app that grows and that someone else will maintain with me.

## Options

| Option | For | Against |
|---|---|---|
| **BLoC / Cubit** | explicit events and states, logic testable as plain Dart with `bloc_test`, the same shape in every feature | more types per feature |
| Riverpod | concise, flexible dependency management | more ways to do the same thing; structure depends more on habits |
| `setState` + services | least code | logic ends up in widgets; hard to test states like "refresh failed but keep the list" |

## Decision

- **BLoC.** A `Bloc` with sealed events where ordering matters (the product list, see 0004); a `Cubit` where a
  method call is enough (login, session, detail).
- **Layers per feature:** `data` (API + repository + models) → `bloc` → `presentation`. Plain-Dart `core`
  underneath, the composition root (`app/dependencies.dart`) on top. Platform code (`flutter_secure_storage`)
  lives behind an interface in `platform/`.
- **Rules as a test, not a wiki page.** `test/architecture_test.dart` resolves every import in `lib/` and fails if
  one breaks a rule; the test also proves the checker catches each kind of violation.
- **No DI package.** Constructors and one composition root; `RepositoryProvider` hands repositories to the widget
  tree. For this size a container adds indirection without value.

## Consequences

- Blocs, the session and the API layer are tested without a widget tree (most of the 149 tests run in
  milliseconds).
- Adding a feature means the same three folders; the architecture test tells a newcomer when an import is wrong.
- Some ceremony for small screens; Cubits keep it down.
