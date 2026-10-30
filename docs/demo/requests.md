# Dummy Shop · demo request log

Every call the app made to `dummyjson.com` while recording `dummy-shop-demo.mp4`, in order. Times are from the start of the recording.

- Passwords, refresh tokens and `Authorization` headers are masked (`•••••`).
- Two things were staged on purpose and are marked **simulated**: one `401` (an expired access token, to show refresh and retry) and a lost connection for API calls. Every other response is the real DummyJSON API.
- Recorded from a web build of the same code at Android phone size (412×900).

## 1 / 7 · Sign in

A wrong password first, then the test account. Tokens go to secure storage.

| time | request | status | ms | notes |
|---|---|---|---|---|
| 0:11 | `POST /auth/login` | 400 | 828 | password ••••• → "Invalid credentials" |
| 0:14 | `POST /auth/login` | 200 | 539 | password ••••• → Emily Johnson; access + refresh token → secure storage |
| 0:15 | `GET /products?limit=20&skip=0` | 200 | 676 | Bearer ••••• · 20 items, skip 0 of 194 · select=id,title,price,… |

## 2 / 7 · Infinite scroll

The next page is requested before the end of the list (prefetch).

| time | request | status | ms | notes |
|---|---|---|---|---|
| 0:21 | `GET /products?limit=20&skip=20` | 200 | 384 | Bearer ••••• · 20 items, skip 20 of 194 · select=id,title,price,… |

## 3 / 7 · Expired token

The server answers 401 (simulated here): one refresh, one retry. The user notices nothing.

| time | request | status | ms | notes |
|---|---|---|---|---|
| 0:37 | `GET /products?limit=20&skip=40` | 401 | 84 | Bearer ••••• → 401: the app refreshes once, then retries once **simulated expired token** |
| 0:37 | `POST /auth/refresh` | 200 | 460 | refreshToken ••••• → new access + refresh token |
| 0:38 | `GET /products?limit=20&skip=40` | 200 | 465 | Bearer ••••• · 20 items, skip 40 of 194 · select=id,title,price,… |

## 4 / 7 · No connection

The next page fails: the list stays and offers "Try again".

| time | request | status | ms | notes |
|---|---|---|---|---|
| 0:42 | *connection lost* | | | simulated for API calls |
| 0:54 | `GET /products?limit=20&skip=60` | offline |  | no connection → the list stays, "Try again" under it **simulated offline** |
| 1:03 | *connection back* | | | the user taps "Try again" |
| 1:05 | `GET /products?limit=20&skip=60` | 200 | 319 | Bearer ••••• · 20 items, skip 60 of 194 · select=id,title,price,… |

## 5 / 7 · Pull to refresh

A fresh first page; the indicator stops when the bloc is done.

| time | request | status | ms | notes |
|---|---|---|---|---|
| 1:14 | `GET /products?limit=20&skip=0` | 200 | 460 | Bearer ••••• · 20 items, skip 0 of 194 · select=id,title,price,… |

## 6 / 7 · Product detail

Image, title and price show at once (from the list); the rest loads in.

| time | request | status | ms | notes |
|---|---|---|---|---|
| 1:18 | `GET /products/1` | 200 | 476 | Bearer ••••• · "Essence Mascara Lash Princess" · 3 reviews |

## 7 / 7 · Restart and sign out

On restart the session comes back from secure storage (GET /auth/me). Sign out clears it.

| time | request | status | ms | notes |
|---|---|---|---|---|
| 1:28 | *app restarted* | | | no sign-in screen: tokens read from secure storage |
| 1:30 | `GET /auth/me` | 200 | 1072 | Bearer ••••• → Emily Johnson |
| 1:31 | `GET /products?limit=20&skip=0` | 200 | 768 | Bearer ••••• · 20 items, skip 0 of 194 · select=id,title,price,… |
| 1:34 | *sign out* | | | tokens cleared locally (DummyJSON has no logout endpoint) |

The `select` parameter on `/products` asks only for the fields the list shows: `id,title,category,price,discountPercentage,rating,stock,thumbnail,brand`.
