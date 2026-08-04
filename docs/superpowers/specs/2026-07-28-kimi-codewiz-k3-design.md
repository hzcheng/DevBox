# Kimi CLI via CodeWiz K3 Design

## Goal

Make `kimi` use CodeWiz's Kimi K3 model by default inside DevBox without
copying CodeWiz SSO credentials into Kimi's configuration.

## Architecture

Kimi CLI will send OpenAI-compatible chat requests to the existing local
CodeWiz proxy at `http://127.0.0.1:8089/v1`. The proxy will continue to load
the current CodeWiz login from `~/.local/share/codewiz/auth.json`, attach the
required internal authentication headers, and forward requests to the CodeWiz
OpenAI-compatible gateway.

The model identifier sent upstream is `kimi-k3`. The local Kimi model alias
is `codewiz/kimi-k3`.

## Configuration

At container startup, DevBox will merge these managed entries into
`${DEV_HOME}/.kimi/config.toml`:

```toml
default_model = "codewiz/kimi-k3"
default_thinking = true

[providers.codewiz]
type = "kimi"
base_url = "http://127.0.0.1:8089/v1"
api_key = "dummy"

[models."codewiz/kimi-k3"]
provider = "codewiz"
model = "kimi-k3"
max_context_size = 1000000
capabilities = ["thinking", "image_in"]
```

The merge will preserve unrelated user settings, providers, and models. It
will update only the top-level defaults and the `providers.codewiz` and
`models."codewiz/kimi-k3"` tables owned by DevBox. The resulting file will be
owned by `DEV_USER`.

## Proxy Changes

The CodeWiz proxy will recognize `kimi-k3` as an OpenAI-compatible model.
This ensures the proxy:

- adds the internal `api-key` header;
- strips compatibility fields unsupported by the upstream model when needed;
- routes Kimi CLI's `/v1/chat/completions` request through the existing OpenAI
  gateway path.

A `kimi3` prefix alias will map to `kimi-k3` for consistency with the
existing Kimi aliases.

## Credentials and Security

Kimi's config will contain only the non-secret placeholder API key required by
the OpenAI client library. CodeWiz SSO tokens and user identity remain in the
mounted CodeWiz auth directory and are read by the local proxy. No SSO token,
email address, or internal compatibility key will be copied into
`~/.kimi/config.toml`.

If CodeWiz credentials are absent, the existing proxy startup behavior remains
the source of the error; Kimi-specific setup does not fabricate credentials.

## Startup Ordering

The Kimi configuration merge runs after the development home is initialized
and before interactive use. It does not require the proxy to be running while
writing the file. The existing proxy startup later in `start-services.sh`
provides the runtime endpoint.

## Verification

The change will be verified with:

1. focused tests for the Kimi config merge and K3 proxy classification;
2. `bash -n devbox/scripts/start-services.sh`;
3. `docker compose config`;
4. a minimal `kimi --quiet --prompt ...` request against a running proxy when
   valid CodeWiz credentials are available.

The smoke test succeeds only when the command exits with status zero and the
model returns the expected short response.
