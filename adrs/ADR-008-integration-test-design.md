# ADR-008: Integration Test Design

## Status

Accepted

## Date

2026-04-28

## Context

Having established in ADR-004 that all tests run against a live OpenSearch node with no HTTP
mocking, this ADR records the specific structural and scoping decisions made when designing
the integration test suite for `opensearch-sugar`.

The key questions were:
- How to organize spec files (per class vs. per feature)
- How to isolate tests from each other
- How to handle slow ML model tests
- How to share the client setup across specs
- What Sugar-owned behavior is in scope vs. what is delegated and therefore out of scope
- What to do about unimplemented stub methods (`index_document`, `index_jsonl_file`)

## Decision

### File organization: per feature, not per class

Spec files are organized by feature cluster rather than by class. The `Client` and `Index`
classes are large enough that a single file per class would become unwieldy. Feature-based
files are independently runnable via `--pattern` and keep each file focused on one concern
with its own setup.

```
spec/
  support/
    opensearch_client.rb        # shared client setup helper
  opensearch/sugar/
    client/
      connection_spec.rb        # ping, raw_client type
      index_management_spec.rb  # has_index?, index_names, open_or_create, []
      settings_spec.rb          # update_settings (cluster-level settings)
    index/
      lifecycle_spec.rb         # Index.open, Index.create, delete!
      document_spec.rb          # count, clear!, delete_by_id, index_document, index_jsonl_file
      settings_spec.rb          # settings, update_settings (index-level)
      mappings_spec.rb          # mappings, update_mappings
      aliases_spec.rb           # aliases, create_alias
      analyzer_spec.rb          # all_available_analyzers, test_analyzer_by_name, test_analyzer_by_fieldname, test_analyzer_by_definition
    models/                     # tagged :slow, :models — excluded from default run
      registration_spec.rb
      lookup_spec.rb
      lifecycle_spec.rb
      pipeline_spec.rb
```

### Test isolation

Each spec that creates an index uses a uniquely named index per example:

```ruby
let(:index_name) { "sugar_test_#{SecureRandom.hex(6)}" }
```

Cleanup is registered with an `after` hook:

```ruby
after { client.indices.delete(index: index_name) rescue nil }
```

The `rescue nil` is intentional: if a test fails before the index is created, cleanup must
not itself raise. No global sweep is used.

### No raw OpenSearch::Client in specs

Specs interact exclusively through `OpenSearch::Sugar::Client`. No test may call
`OpenSearch::Client` directly. This keeps specs honest about what Sugar provides vs. what
would require bypassing the abstraction.

### Shared client setup

A `spec/support/opensearch_client.rb` helper loads `spec/env.testing` via `dotenv` and
defines an RSpec shared context that exposes `let(:client)`. Every spec file includes this
shared context. The client is configured for the local Docker cluster with SSL verification
disabled.

### ML model tests: tagged and excluded by default

All specs in `spec/opensearch/sugar/models/` are tagged `:slow` and `:models`. They are
excluded from the default `bundle exec rspec` run via RSpec filter configuration. To run
them:

```bash
bundle exec rspec --tag models
```

### Scope: Sugar-owned behavior only

Tests cover only behavior implemented by Sugar. Delegated methods (e.g., `client.search`,
`client.index`, `client.bulk`) are not tested — `opensearch-ruby` is responsible for those.

The guiding question for inclusion: *"Does Sugar add logic here, or is it a straight
pass-through to the underlying client?"*

### `update_settings` and `update_mappings` raise on failure

The existing implementation returns an error Hash on failure, which is inconsistent with
ADR-005. As part of this work, both methods are changed to raise `OpenSearch::Sugar::Error`
on failure (after attempting to reopen the index). This is a breaking change from the
previous behavior.

### `index_document` and `index_jsonl_file`

Both stub methods are implemented as simple, intentionally inefficient implementations
suitable for small-scale and testing use only. A TODO is left in the code for a future
bulk-API implementation.

```ruby
# index_document: requires both arguments
def index_document(doc, id)
  # TODO: inefficient; replace with bulk API for large-scale use
  client.index(index: name, id: id, body: doc)
end

# index_jsonl_file: accepts a String path or any IO-like object (StringIO, File)
def index_jsonl_file(source, id_field:)
  # TODO: inefficient; replace with bulk API for large-scale use
  io = source.is_a?(String) ? File.open(source) : source
  io.each_line do |line|
    doc = JSON.parse(line, symbolize_names: true)
    id = doc.fetch(id_field.to_sym) {
      raise ArgumentError, "id_field :#{id_field} not found in document"
    }
    index_document(doc, id.to_s)
  end
end
```

Specs for these methods use `StringIO` to avoid filesystem dependencies.

## Consequences

### Positive

- Feature-based files are independently runnable and focused
- Unique index names eliminate inter-test interference without a global sweep
- ML tests are opt-in; default suite runs fast
- Restricting specs to Sugar's API surface keeps the test suite honest
- Implementing the stubs closes a gap in the public API and gives tests something real to run against

### Negative

- `update_settings`/`update_mappings` behavior change (raise vs. return Hash) is breaking for
  any existing callers relying on checking `result[:status]`
- `index_document` and `index_jsonl_file` are explicitly not production-grade; callers doing
  bulk loads must use the raw `client.bulk` API until a proper bulk implementation is added

### Neutral

- `spec/env.testing` must not be committed with real credentials; `.gitignore` covers it
- The `spec/opensearch/sugar_spec.rb` skeleton (with wrong constant casing and a hardcoded
  failure) is deleted and replaced by the new structure

## Alternatives Considered

**Per-class spec files**
Considered and rejected; the `Client` and `Index` classes are large enough that single-file
specs would become hard to navigate and run selectively.

**Global `after(:suite)` sweep to delete all `sugar_test_*` indexes**
Considered as a safety net. Rejected as primary strategy in favor of per-example cleanup,
which makes cleanup intent explicit. A sweep could be added as a belt-and-suspenders measure
in the future.

## Documentation Requirements

- `CONTRIBUTING` guide must document the `:models` tag and how to run ML tests.
- `spec/env.testing` must document all required environment variables inline.
