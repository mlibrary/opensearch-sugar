# opensearch-sugar

[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.1.0-ruby.svg)](https://www.ruby-lang.org/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A Ruby gem that wraps the [opensearch-ruby](https://github.com/opensearch-project/opensearch-ruby)
client with a more convenient, object-oriented API for managing indexes, documents,
settings, mappings, and ML models — while giving you full access to the underlying
client whenever you need it.

## Quick example

```ruby
require "opensearch/sugar"

client = OpenSearch::Sugar::Client.new   # reads OPENSEARCH_URL / USER / PASSWORD

index = client.open_or_create_index("products")

index.update_mappings(
  mappings: {
    properties: {
      title:    { type: "text" },
      category: { type: "keyword" },
      price:    { type: "float" }
    }
  }
)

index.index_document({ title: "Dune", category: "fiction", price: 12.99 }, "isbn-0441013597")
index.refresh   # make the document immediately searchable

results = client.search(
  index: "products",
  body: { query: { match: { title: "dune" } } }
)
puts results["hits"]["hits"].first.dig("_source", "title")
#=> "Dune"
```

`client.search` (and every other `opensearch-ruby` method) works directly on the Sugar
client via delegation — no need to unwrap anything.

See the [Tutorial](docs/TUTORIAL.md) for a full walkthrough.

## Installation

```ruby
# Gemfile
gem "opensearch-sugar"
```

```bash
bundle install
```

## Configuration

Connection details are read from environment variables:

| Variable | Used for | Default |
|----------|----------|---------|
| `OPENSEARCH_URL` | Cluster URL | `https://localhost:9000` |
| `OPENSEARCH_HOST` | Cluster URL (lower priority) | — |
| `OPENSEARCH_USER` | Basic auth user | `"admin"` |
| `OPENSEARCH_PASSWORD` | Basic auth password | — |
| `OPENSEARCH_INITIAL_ADMIN_PASSWORD` | Basic auth password (lower priority) | — |

Any keyword argument accepted by `OpenSearch::Client.new` can be passed to
`OpenSearch::Sugar::Client.new` and will override the defaults.

## Documentation

- **[Tutorial](docs/TUTORIAL.md)** — step-by-step walkthrough building a searchable book catalog from scratch
- **[How-to Guides](docs/HOWTO.md)** — practical recipes for connection options, document CRUD, search, aliases, ML models, error handling, and more
- **[API Reference](docs/REFERENCE.md)** — complete method reference for `Client`, `Index`, and `Models`

## Development

Start a local OpenSearch cluster:

```bash
docker compose up -d
```

OpenSearch takes ~30 seconds to be ready. Wait until the following command succeeds
before running the test suite:

```bash
curl -sk https://localhost:9200 -u admin:${OPENSEARCH_INITIAL_ADMIN_PASSWORD} | grep -q tagline && echo "Ready"
```

Run the specs:

```bash
bundle exec rspec
```

To generate a coverage report:

```bash
bundle exec rake coverage
```

or:

```bash
COVERAGE=true bundle exec rspec
```

Coverage reports are written to `coverage/index.html`.

To see full HTTP request/response logs during a run:

```bash
OPENSEARCH_LOG=true bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome at
<https://github.com/mlibrary/opensearch-sugar>. Please open an issue before
submitting large changes.

## License

Available as open source under the [MIT License](LICENSE).
