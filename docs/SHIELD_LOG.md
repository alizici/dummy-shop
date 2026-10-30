# Code shield log

Every intentional change to locked critical code (`guardrails/shield.py approve`). Historical record; the current lock list is `shield.json`.

| time (UTC) | lock | fingerprint | commit | reason |
|---|---|---|---|---|
| 2026-10-30 12:27 | session-refresh | - → b53cfcb4f4026c3a | ?+ | Initial lock: single-flight refresh; only a rejected refresh ends the session; a refresh can't outlive its session (docs/decisions/0003). |
| 2026-10-30 12:27 | auth-retry | - → fae8eae85e15f5d2 | ?+ | Initial lock: one refresh and one retry per 401, a second 401 is final (docs/decisions/0003). |
