# link-check

Link Check: URL status, response time, and HTTPS check. Serverpod backend with a Flutter web client by [elghaly](https://elghaly.dev/).

## Server link-check API

The `linkCheck.check` endpoint performs an outbound HTTP(S) probe on a user-supplied URL. Safeguards include:

- **URL validation** — only `http`/`https`, no embedded credentials, length limits
- **SSRF / internal network blocking** — rejects localhost, RFC1918, link-local, metadata, and related targets (hostname and resolved IPs, including redirect hops)
- **Timeouts** — connect and overall request deadlines
- **Response size cap** — response bodies are drained up to a fixed byte limit
- **Rate limiting** — per-client sliding window (by remote address)

## Development

```bash
cd link_check_server
serverpod generate   # after model/endpoint changes
dart test
serverpod start      # from repo root
```
