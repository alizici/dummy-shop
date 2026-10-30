# 0004 · Product list: pagination, refresh and their ordering

**Status:** accepted · 2026-10-30

## Context

`GET /products?limit&skip&select` returns `{products, total, skip, limit}` (194 products). The list needs a first
load, pull to refresh and pagination, each with its own loading and failure behavior.

The classic race: the user scrolls (page 2 starts loading), then pulls to refresh. The refresh answers first and
replaces the list; then page 2 lands and is appended to the refreshed list, giving 40 items where 20 belong.

## Decision

- **Offset pagination**, 20 per page, requesting only the fields the list shows (`select=`). The state keeps
  `nextSkip`, the server offset of the next page (`page.skip + page.items.length`), rather than using
  `items.length`: after dedupe the two can differ, and paging by `items.length` would ask for the same page forever
  when a page brings nothing new. The end is `nextSkip >= total`, and an empty page ends the list whatever `total`
  says.
- **Events are handled one at a time** (`sequential()` = `asyncExpand`). A refresh waits for a page in flight
  instead of racing it. This removes the race instead of patching it with request IDs.
- **`ProductsNextPageRequested(nextSkip)`** carries the offset it was made for. A request for a list that has moved
  on is ignored, so a scroll listener firing many times loads each page once.
- **Dedupe by id** when appending, in case the catalog shifted between pages.
- **Failures keep what works:** a failed first load replaces the list with an error and "Try again"; a failed refresh
  keeps the list and shows a snackbar once; a failed next page keeps the list and shows a retry at the end. Only
  that button (`isRetry: true`) loads again; requests queued before the failure don't retry on their own.
- **`ProductsRefreshed` carries a `Completer`**, completed when the refresh is over, so `RefreshIndicator` spins
  exactly as long as the work.
- **Prefetch:** the next page is requested 600 px before the end. A short first page that doesn't fill the screen
  asks for more after layout, since no scroll event would ever come.

## Consequences

- `products_bloc_test` answers the refresh before the page on purpose; with concurrent handling that test fails
  (checked by removing `sequential()`). Other tests cover a page with nothing new, an empty page under an
  over-reported total, and a request queued before a failure.
- A refresh during a slow page waits for it. On a list this size that's acceptable and predictable; on an expensive
  feed I'd cancel the page instead (`restartable` for refresh, with the list replaced atomically).
