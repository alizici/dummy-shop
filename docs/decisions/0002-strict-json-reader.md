# 0002 · A strict JSON reader instead of code generation

**Status:** accepted · 2026-10-30

## Context

The app reads four DummyJSON responses (login, `/auth/me`, a product page, a product). DummyJSON leaves some fields
out (`brand` is missing for groceries). There is no OpenAPI spec.

The failure I want to avoid: a response that doesn't match the model and still turns into valid-looking data, like
a missing price becoming `0`, or a bad date becoming 1 January 1970. That kind of bug shows up on screen weeks later,
far from its cause.

## Options

| Option | For | Against |
|---|---|---|
| `json_serializable` / `freezed` | standard, less hand-written code | a build step and generated files for four models; defaults and lenient converters are easy to add and hide problems |
| OpenAPI generator | the right tool when a spec exists | there is no spec here |
| `map['price'] as double` by hand | no dependencies | `5` (an `int`) crashes the cast; errors don't say where |
| **Strict `JsonReader`** | ~140 lines, typed reads, errors name the JSON path | hand-written `fromJson` per model |

## Decision

`core/json/JsonReader`:

- Required reads (`string`, `integer`, `number`...) throw `ResponseFormatException` for missing, `null` or wrong-type
  values. Optional reads (`stringOrNull`) return `null` only for missing or `null`; a present value of the wrong type
  still throws.
- No silent defaults. `stringListOrEmpty` exists, used only where "absent" really means "none" (tags, images).
- Errors carry the path: `$.products[2].price: expected a number, found a string`.
- Numbers accept whole values (`5` for a price), because JSON doesn't distinguish them.
- `guardApi` turns a `ResponseFormatException` into `InvalidResponseFailure`, so a broken response is a handled error
  with a message, never a crash.

The list asks only for the fields it reads (`select=`), and a test checks that `ProductSummary.fields` matches what
`fromJson` reads in a real response.

## Consequences

- Models are tested against real, saved responses (`test/fixtures`), and the live contract test parses the whole
  catalog, so drift is caught by a test, not by a user.
- Each model has a short hand-written `fromJson`. With a real OpenAPI spec I'd generate the client and keep a
  repository layer on top; the reader idea (fail loudly, with a path) still applies to the generator's settings.
