# Dummy Shop · working notes for Claude Code

Flutter + BLoC app against DummyJSON (sign in, product list, detail). What and why: `README.md`; layers, errors and
session flow: `docs/architecture.md`; decisions: `docs/decisions/`; assumptions: `docs/OPEN_QUESTIONS.md`.

## Commands

```bash
flutter pub get
flutter analyze                                   # must be clean (infos count)
dart format --set-exit-if-changed lib test        # page width 120, set in analysis_options.yaml
flutter test                                      # whole suite, ~20 s
flutter test test/core/session_manager_test.dart  # one file
flutter test --run-skipped --tags live            # real DummyJSON contract check (network)
bash tool/refresh_fixtures.sh                     # re-download test/fixtures from the real API
```

## Rules

- **Layers:** `presentation → bloc → data → core`, composition root in `app/dependencies.dart`, device code only in
  `platform/`. `test/architecture_test.dart` enforces it; if it fails, fix the import, don't edit the rule.
- **Blocs are plain Dart:** `package:bloc`, never `flutter_bloc` or Flutter in `bloc/` and `data/`.
- **Errors:** every backend call goes through `guardApi` and ends as an `ApiFailure`. User-facing text for failures
  lives only in `app/failure_message.dart` (exhaustive switch).
- **JSON:** `JsonReader` only. No silent defaults; optional means `...OrNull` and is a deliberate choice.
- **Session:** only `SessionManager` touches tokens. Login and refresh use the `public` Dio; everything else the
  `authorized` one. Only a rejected refresh ends a session.
- **Cubits that can outlive their page** check `isClosed` before emitting after an `await`.
- **Tests:** HTTP through `test/support/fake_server.dart`; fixtures are real responses and read-only. A new
  behavior gets a test that fails without it: break the code once and watch it go red.

## Guardrails (from github.com/alizici/claude-code-guardrails)

Off by default, so opening the repo doesn't run anything. To switch the hooks on for yourself:
`cp .claude/settings.example.json .claude/settings.local.json` (gitignored). They run `guardrails/guard.py` and
`guardrails/deletion_guard.py`:

- End of turn: `analyze`, `format`, `tests` and the code shield run when matching files changed. A red gate keeps
  the turn open. Fix the cause; never weaken a test or a rule to get past it.
- Read-only: `test/fixtures/*.json`, `pubspec.lock`, `docs/SHIELD_LOG.md` (regenerate instead).
- Ask first: `pubspec.yaml`, `test/architecture_test.dart`, `shield.json`, `.claude/agents/**`, `flutter pub add/upgrade`.
- Code shield (`shield.json`): `session_manager.dart` (lock `session-refresh`) and `auth_interceptor.dart` (lock
  `auth-retry`) are locked. Change them only when asked, run `python3 guardrails/shield.py test <lock>`; approving
  is the user's call.
- Deleting an important line (function, test, guard clause, doc line) needs a declaration first:
  `python3 guardrails/deletion_guard.py allow <file> --line "<text>" --reason "<why>"`.
- Role agents in `.claude/agents/`: `card-auditor` → `test-writer` → `implementer` → `reviewer`. The writer
  can't touch `lib/`, the implementer can't touch `test/`, auditor and reviewer can't write.

Setup check: `python3 guardrails/guard.py check` (last line `ok`). Git hooks for the shield:
`sh guardrails/install_git_hooks.sh`.
