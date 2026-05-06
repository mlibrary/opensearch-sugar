# ADR-006: SSL Enabled by Default; Explicit Opt-Out for Development

## Status

Accepted

## Date

2026-04-28

## Context

`OpenSearch::Sugar::Client` wraps `OpenSearch::Client` and must decide what default transport
security settings to apply when the caller does not specify them. OpenSearch clusters in
production are almost universally deployed with TLS. The risk of accidentally connecting
without TLS — exposing credentials or data in transit — is meaningful and asymmetric: the
cost of a misconfigured production cluster far outweighs the minor inconvenience of explicitly
disabling SSL for local development.

The two realistic positions are:

1. **SSL off by default, opt-in for production** — easy local setup, but a forgotten
   production configuration is a silent security failure.
2. **SSL on by default, explicit opt-out for development** — requires one extra line in
   development, but the default is always secure.

## Decision

SSL is enabled by default. Callers who need to connect to a development cluster without
certificate verification must explicitly pass `ssl: { verify: false }` in transport options.

```ruby
# Production — SSL on, certificate verified (default; no extra config needed)
client = OpenSearch::Sugar::Client.new(
  host: "https://search.production.example.com:9200",
  user: ENV["OPENSEARCH_USER"],
  password: ENV["OPENSEARCH_PASSWORD"]
)

# Development — SSL on but verification disabled
client = OpenSearch::Sugar::Client.new(
  host: "https://localhost:9200",
  user: "admin",
  password: ENV["OPENSEARCH_PASSWORD"],
  transport_options: {
    ssl: { verify: false }
  }
)
```

Documentation leads with the production-safe form and explicitly explains how to disable
verification for development. The Docker Compose test environment uses `ssl: { verify: false }`
in `spec/env.testing`.

## Consequences

### Positive

- **Secure by default**: a caller who copies the simplest example from the README will get
  a TLS-secured connection. There is no "forgot to enable SSL in prod" failure mode.
- **Explicit intent in dev code**: `ssl: { verify: false }` in development configuration
  is a visible, searchable signal that certificate verification is intentionally disabled.
  Code review can flag it if it appears in production configuration.

### Negative

- **Friction for local development**: first-time setup requires understanding why the default
  connection attempt to a local Docker cluster fails and how to disable verification. Without
  clear documentation this is confusing.
- **No plaintext (`http://`) shortcut**: callers who want plain HTTP (no TLS at all) must
  also configure transport options explicitly. The documentation must cover this case.

### Neutral

- The underlying `OpenSearch::Client` and the `Faraday` HTTP adapter handle the actual TLS
  negotiation; Sugar does not implement TLS logic itself.
- Credentials must always be provided via environment variables (e.g., loaded from
  `spec/env.testing` with `dotenv`); hardcoding passwords in source is never acceptable
  regardless of environment.

## Alternatives Considered

**SSL off by default**
Rejected. The security asymmetry is clear: forgetting to enable SSL in production is a serious
vulnerability with no automatic safeguard. Forgetting to disable SSL verification in development
is a minor inconvenience that produces a loud, obvious error.

## Documentation Requirements

- README must include both the production (SSL on) and development (verify: false) connection
  examples, with a prominent note that `verify: false` is for development only.
- HOWTO "Connection and Configuration" section must appear at the top of the guide and cover
  both cases.
- EXPLANATION must explain why SSL is on by default and what `verify: false` does (and does
  not) protect against.
