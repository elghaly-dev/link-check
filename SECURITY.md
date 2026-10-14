# SSRF security checklist

Link Check outbound probes are guarded in `link_check_server/lib/src/link_check/`. Each row is verified by automated tests in `link_check_server/test/unit/`.

| # | Control | Status | Proof test(s) |
|---|---------|--------|---------------|
| 1 | **http/https only** — reject `file:`, `gopher:`, `ftp:`, `data:`, `javascript:`, and `user:pass@` | **PASS** | `link_check_security_test.dart` — groups “scheme and credentials (SSRF #1)” |
| 2 | **Block private/loopback/link-local/metadata IPs** — 127/8, ::1, 10/8, 172.16/12, 192.168/16, 169.254/16, fe80::/10, fc00::/7, 100.64/10, 0/8, ::ffff: mapped | **PASS** | `link_check_security_test.dart` — groups “blocked networks (SSRF #2)” |
| 3 | **Normalize encoded hosts** — decimal/octal/hex IPv4, trailing dot, punycode (`xn--`) | **PASS** | `link_check_security_test.dart` — group “host normalization (SSRF #3)” |
| 4 | **DNS rebinding** — resolve once, TCP connect to that checked IP via `HttpClient.connectionFactory` | **PASS** | `link_check_security_test.dart` — “DNS pinning (SSRF #4)”; `link_check_service.dart` — `_sendRequest` + `connectionFactory` |
| 5 | **Redirects manual, max 5, re-check 1–4 on every hop** | **PASS** | `link_check_service.dart` — `followRedirects = false`, hop loop with `validateRequestUrl` + `resolveConnectAddress`; `link_check_security_test.dart` — `maxRedirects == 5` |
| 6 | **Ports 80/443 only, 3s connect, 10s total, 1 MB body max, GET/HEAD only** | **PASS** | `link_check_security_test.dart` — “ports and limits (SSRF #6)”; `link_check_service.dart` — HEAD with GET fallback, `_drainLimited` |
| 7 | **No cookies/auth headers out, no raw body or internal IPs in errors, rate limit per client** | **PASS** | `link_check_service.dart` — only `User-Agent` set; generic error strings; `link_check_rate_limiter.dart` + endpoint + tests in “LinkCheckRateLimiter (SSRF #7)” |

Maintainers: after changing validation or fetch logic, run `cd link_check_server && dart test` and update this table if a row’s proof tests move.
