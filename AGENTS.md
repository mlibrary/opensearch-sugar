# opensearch-sugar — Agent Instructions

## What this project is

`opensearch-sugar` is a Ruby gem that wraps the [`opensearch-ruby`](https://github.com/opensearch-project/opensearch-ruby)
client with a more convenient, object-oriented API. It provides three main classes:

- **`OpenSearch::Sugar::Client`** — connects to an OpenSearch cluster; adds index management,
  settings/mappings helpers, and delegated access to all underlying `OpenSearch::Client` methods
- **`OpenSearch::Sugar::Index`** — represents a single index with methods for CRUD on documents,
  settings, mappings, aliases, and text analysis
- **`OpenSearch::Sugar::Models`** — manages ML models via the OpenSearch ML Commons plugin
  (register, deploy, list, delete, and build embedding pipelines)

This is a plain Ruby gem. It has no Rails dependency and must not use Rails-specific gems or patterns.

## File structure

```
lib/
  opensearch/
    sugar.rb                  # Top-level require; defines OpenSearch::Sugar module
    sugar/
      client.rb               # OpenSearch::Sugar::Client (SimpleDelegator wrapper)
      index.rb                # OpenSearch::Sugar::Index
      index/                  # Index sub-components
      models.rb               # OpenSearch::Sugar::Models
      version.rb              # OpenSearch::Sugar::VERSION

sig/
  opensearch/
    sugar.rbs                 # RBS type signatures for the public API

spec/
  spec_helper.rb
  opensearch_integration_spec.rb
  env.testing                 # dotenv file for the test cluster

docs/
  REFERENCE.md                # Complete API reference
  HOWTO.md                    # Problem-solving recipes
  TUTORIAL.md                 # Step-by-step learning guide
  EXPLANATION.md              # Conceptual background
  DELEGATED_METHODS_ANALYSIS.md

adrs/                         # Architecture Decision Records
```

## Code style

- **Formatter**: Ruby `standard` gem with default settings. Config at `.standard.yml`. Do not suppress rules without a comment explaining why.
- **Line length**: 100 characters (`.editorconfig`).

## Test stack

Tests are written with **RSpec** and live in `spec/`. They are **integration tests** that
require a live OpenSearch node; there is no mocking layer. Spin up a local cluster first:

```bash
docker compose up -d
bundle exec rspec
```

Environment variables for the test cluster are loaded from `spec/env.testing` via `dotenv`.
There is currently no unit-test suite; if you add pure-Ruby logic to `lib/` that can be
tested in isolation, add unit specs alongside it.

## Naming conventions

- **Top-level namespace**: `OpenSearch::Sugar`
- **Classes**: `OpenSearch::Sugar::Client`, `OpenSearch::Sugar::Index`, `OpenSearch::Sugar::Models`
- **Error base class**: `OpenSearch::Sugar::Error < StandardError`
- **Source files**: `snake_case` under `lib/opensearch/sugar/` (e.g. `client.rb`, `models.rb`)
- **Spec files**: mirror source path with `_spec.rb` suffix (e.g. `spec/opensearch/sugar/client_spec.rb`)
- **RBS files**: `snake_case` under `sig/opensearch/sugar/` with `.rbs` extension
- **Script/rake filenames**: `snake_case` (Ruby: `.rb`, bash: `.sh`)

## Type signatures

RBS type signatures for the public API live in `sig/`. When adding or changing public methods,
update the corresponding `.rbs` file to keep signatures in sync. Type-check with `steep check`
if Steep is configured, or validate signatures with `rbs validate`.

## Documentation

- General documentation conventions follow `/Users/dueberb/devel/ai/agent_resources/external_documentation.md`.
- Project metadata conventions (versioning, changelog, release process, CONTRIBUTING, SECURITY) follow
  `/Users/dueberb/devel/ai/agent_resources/project_metadata.md`.
- **Diagrams**: use Mermaid in both ADRs and `docs/` files.

## Ruby idioms and best practices

- Use modern Ruby syntax and idioms (post-3.4) unless there is a compelling reason not to.
- Avoid `_1`-style block variables for readability.
- Use exceptions for error handling rather than Result objects or similar patterns, unless there is a compelling reason to do otherwise.
- Don't use Rails-specific gems or patterns, as this is a general-purpose Ruby gem that does not assume a Rails environment.
- Use YARD for API documentation, with clear comments on all public methods and classes. Include links to relevant OpenSearch documentation where applicable.

## ADRs

All design decisions are recorded in `adrs/`.  Use the template in `adrs/ADR-000-template.md` for consistency.
When making a non-trivial architectural
choice, check the ADRs first. If a decision conflicts with an ADR, raise it explicitly
rather than quietly working around it.
