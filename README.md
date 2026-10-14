# link-check

Link Check: URL status, response time, and HTTPS check. Serverpod backend with a Flutter web client by [elghaly](https://elghaly.dev/).

## Server link-check API

The `linkCheck.check` endpoint performs an outbound HTTP(S) probe on a user-supplied URL. Safeguards include:

- **URL validation** — only `http`/`https`, no embedded credentials, length limits
- **SSRF / internal network blocking** — rejects localhost, RFC1918, link-local, metadata, and related targets (hostname and resolved IPs, including redirect hops)
- **Timeouts** — connect and overall request deadlines
- **Response size cap** — response bodies are drained up to a fixed byte limit
- **Rate limiting** — per-client sliding window (by remote address)

## Flutter web UI

The app in `link_check_flutter` calls `client.linkCheck.check` and shows status, timing, HTTPS, redirects, and server-side validation errors.

```bash
serverpod start      # from repo root — launches server + web app
```

## Development

```bash
cd link_check_server
serverpod generate   # after model/endpoint changes
dart test
cd ../link_check_flutter && flutter test
```

## Serverpod Cloud (scloud)

Deploy from `link_check_server` after you sign in with the Cloud CLI. Do not put secrets in the repo; use `scloud secret set` for sensitive values and `scloud password set` for Serverpod passwords.

```bash
cd link_check_server
dart pub global activate serverpod_cloud_cli
export PATH="$PATH:$HOME/.pub-cache/bin"

# First time: creates/links the Cloud project (you complete login in the browser)
scloud auth login
scloud launch -p link-check

# Later deploys
scloud deploy --await

# Optional: validate packaging without uploading
scloud deploy --wet-run --show-files
```

See [SECURITY.md](SECURITY.md) for the SSRF control matrix and proof tests.
