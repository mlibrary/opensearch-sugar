# ADR-004: Integration Tests Against a Real OpenSearch Node; No HTTP Mocking

## Status

Accepted

## Date

2026-04-28

## Context

`opensearch-sugar` wraps the OpenSearch HTTP API. Its correctness depends on real
request/response semantics: field ordering in bodies, HTTP status codes, error shapes,
and side effects (index creation, document persistence, model deployment state). The question
is whether tests should run against a live cluster or use some form of HTTP-level mocking.

The main options evaluated were:

- **VCR (cassette recording)**: record real HTTP interactions once, replay from cassettes in CI
- **WebMock / stub_request**: hand-write HTTP stubs for each tested scenario
- **Live integration tests with a Dockerized OpenSearch node**: run all tests against a real
  cluster spun up via `docker compose`

## Decision

All tests are integration tests that run against a live OpenSearch node. There is no mocking
layer. A `docker compose up -d` brings up the cluster before running `bundle exec rspec`.

```bash
# Start the cluster
docker compose up -d

# Run the full suite
bundle exec rspec
```

Tests are responsible for cleaning up their own fixtures (indexes, models, pipelines) and must
not leave traces in the cluster after they complete.

VCR was explicitly evaluated and rejected.

## Consequences

### Positive

- **High fidelity**: tests exercise the actual HTTP client, auth, TLS, serialization, and
  OpenSearch response parsing — the exact code paths that matter in production.
- **No cassette maintenance**: recorded cassettes drift as the OpenSearch API evolves; with live
  tests there is nothing to regenerate or keep in sync.
- **Catches real regressions**: version bumps of `opensearch-ruby` or OpenSearch itself are
  immediately visible in the test results.
- **Simple setup**: `docker compose up -d && bundle exec rspec` is the entire test workflow;
  no cassette directory, no VCR configuration, no per-test recording modes.

### Negative

- **Requires Docker**: contributors without Docker cannot run the suite locally without
  additional setup.
- **Slower than mocked tests**: the suite waits for network I/O and OpenSearch processing;
  ML model deployment tests are particularly slow due to polling.
- **Flakiness risk**: tests are sensitive to cluster state. Poorly isolated tests can interfere
  with each other if cleanup is missed.
- **No offline CI without a real cluster**: CI pipelines must be able to start a Docker service
  container; environments that cannot do so cannot run the suite.

### Neutral

- Unit tests for pure Ruby logic (no I/O) are welcome alongside integration tests. If logic
  that can be tested in isolation is added to `lib/`, unit specs should be added as well.
- The `spec/env.testing` file (loaded via `dotenv`) supplies cluster credentials; this file
  must not be committed with production credentials.

## Alternatives Considered

**VCR (cassette recording)**
Evaluated and rejected. VCR adds complexity (cassette storage, recording modes, sensitive-data
filtering) without sufficient benefit for this gem. The core value of these tests is verifying
real interactions with OpenSearch; replaying stale cassettes undermines that value and creates
a maintenance burden.

**WebMock / hand-written stubs**
Rejected for the same reasons: stubs are approximations of the real API and would require
manual updates whenever the response shape changes. For a thin wrapper gem, testing against
the real thing is more reliable than maintaining an approximate fake.

## Documentation Requirements

- The README and CONTRIBUTING guide must document the Docker prerequisite and the
  `docker compose up -d` + `bundle exec rspec` workflow.
- The `spec/env.testing` file must document all required environment variables.
