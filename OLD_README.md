# OpenSearch::Sugar

[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.1.0-ruby.svg)](https://www.ruby-lang.org/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A Ruby gem that provides an elegant, intuitive interface for working with OpenSearch. OpenSearch::Sugar wraps the official [opensearch-ruby](https://github.com/opensearch-project/opensearch-ruby) client with a friendly API that simplifies common operations while still giving you full access to the underlying client when needed.

## Why OpenSearch::Sugar?

The official OpenSearch Ruby client is powerful but verbose. OpenSearch::Sugar makes common tasks more intuitive:

- **Simpler syntax** for creating and managing indexes
- **Convenient helpers** for bulk operations, aliases, and document management
- **ML model management** with an easy-to-use interface
- **Full delegation** to the underlying client - use sugar where you want it, raw client where you need it

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'opensearch-sugar'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself:

```bash
$ gem install opensearch-sugar
```

## Quick Start (Tutorial)

### 1. Connect to OpenSearch

```ruby
require 'opensearch/sugar'

# Using environment variables (recommended)
# Set OPENSEARCH_URL, OPENSEARCH_USER, and OPENSEARCH_PASSWORD
client = OpenSearch::Sugar.new

# Or pass connection details explicitly
client = OpenSearch::Sugar.new(
  host: 'https://localhost:9200',
  user: 'admin',
  password: 'admin'
)
```

### 2. Create an Index

```ruby
# Create a new index
index = OpenSearch::Sugar::Index.create(
  client: client,
  name: 'my_index',
  knn: true  # Enable k-NN if needed
)

# Or open an existing index
index = client['my_index']

# Or open if exists, create if doesn't
index = client.open_or_create_index('my_index')
```

### 3. Configure Index Settings and Mappings

```ruby
# Update index settings
index.update_settings(
  settings: {
    analysis: {
      analyzer: {
        my_custom_analyzer: {
          type: 'custom',
          tokenizer: 'standard',
          filter: ['lowercase', 'stop']
        }
      }
    }
  }
)

# Update mappings
index.update_mappings(
  mappings: {
    properties: {
      title: { type: 'text', analyzer: 'my_custom_analyzer' },
      description: { type: 'text' },
      created_at: { type: 'date' },
      tags: { type: 'keyword' }
    }
  }
)
```

### 4. Work with Documents

```ruby
# Get document count
count = index.count

# Delete a document by ID
index.delete_by_id('doc123')

# Clear all documents from index
deleted_count = index.clear!

# Delete the entire index
index.delete!
```

### 5. Analyze Text

```ruby
# Analyze text with a specific analyzer
tokens = index.analyze_text(
  analyzer: 'my_custom_analyzer',
  text: 'The quick brown fox'
)
# => ["quick", "brown", "fox"]

# Analyze text using a field's configured analyzer
tokens = index.analyze_text_field(
  field: 'title',
  text: 'OpenSearch is great!'
)
```

### 6. Manage Aliases

```ruby
# Get current aliases
aliases = index.aliases

# Create a new alias
index.create_alias('my_alias')
```

## How-to Guides

### How to Check if an Index Exists

```ruby
if client.has_index?('my_index')
  puts "Index exists!"
else
  puts "Index not found"
end
```

### How to List All Indexes

```ruby
index_names = client.index_names
puts "Available indexes: #{index_names.join(', ')}"
```

### How to Get Available Analyzers

```ruby
# List all analyzers available to an index
analyzers = index.all_available_analyzers
# or using the alias
analyzers = index.analyzers

puts "Available analyzers: #{analyzers.join(', ')}"
```

### How to Access the Raw OpenSearch Client

```ruby
# OpenSearch::Sugar::Client delegates to the raw client
# You can call any method from opensearch-ruby directly:

response = client.search(
  index: 'my_index',
  body: {
    query: {
      match: { title: 'opensearch' }
    }
  }
)

# Or access the raw client explicitly
raw_client = client.raw_client
```

### How to Work with ML Models

OpenSearch::Sugar provides convenient methods for managing machine learning models:

```ruby
# Access the models interface
models = client.models

# Register and deploy a model
model = models.register(
  name: 'huggingface/sentence-transformers/all-MiniLM-L12-v2',
  version: '1.0.1',
  format: 'TORCH_SCRIPT'
)

# List all models
all_models = models.list

# Get a specific model by name, ID, or nickname
model = models['all-MiniLM-L12-v2']

# Create an ingest pipeline with a model
models.create_pipeline(
  name: 'my_embedding_pipeline',
  model: 'all-MiniLM-L12-v2',
  description: 'Generate embeddings for text fields',
  field_map: {
    'text_field' => 'embedding_field'
  }
)

# Undeploy a model
models.undeploy!('all-MiniLM-L12-v2')

# Delete a model
models.delete!('all-MiniLM-L12-v2')
```

### How to Set Log Level

```ruby
# Set cluster logging level
# See: https://opensearch.org/docs/latest/install-and-configure/configuring-opensearch/logs/
client.set_log_level(logger: 'logger._root', level: 'warn')
```

### How to Handle Connection Settings

```ruby
# View default connection arguments
client.default_args

# Create a client with custom settings
client = OpenSearch::Sugar.new(
  host: 'https://search.example.com:9200',
  user: 'myuser',
  password: 'mypassword',
  retry_on_failure: 3,
  request_timeout: 10,
  log: false,
  transport_options: {
    ssl: { verify: true }
  }
)
```

## API Reference

### OpenSearch::Sugar::Client

The main client class that wraps the OpenSearch client with convenient methods.

**Class Methods:**
- `.new(**kwargs)` - Create a new client instance
- `.raw_client(*args, **kwargs)` - Create a raw OpenSearch::Client instance

**Instance Methods:**
- `#has_index?(name)` - Check if an index exists
- `#index_names` - Get list of all index names
- `#[](index_name)` - Open an index by name
- `#open_or_create_index(index_name)` - Open existing or create new index
- `#delete_index!(index_name)` - Delete an index by name
- `#update_settings(settings, index_name)` - Update index settings
- `#update_mappings(mappings, index_name)` - Update index mappings
- `#set_log_level(logger:, level:)` - Set OpenSearch log level
- `#models` - Access ML models interface
- `#raw_client` - Access the underlying OpenSearch::Client

See the [OpenSearch Client API documentation](https://opensearch.org/docs/latest/clients/ruby/) for all delegated methods.

### OpenSearch::Sugar::Index

Represents an OpenSearch index with methods for management and querying.

**Class Methods:**
- `.open(client:, name:)` - Open an existing index (raises if not found)
- `.create(client:, name:, knn: true)` - Create a new index (raises if exists)

**Instance Methods:**
- `#count` - Get document count
- `#delete!` - Delete the index
- `#refresh` - Force an index refresh (make indexed docs immediately searchable)
- `#clear!` - Delete all documents from the index
- `#delete_by_id(id)` - Delete a specific document
- `#index_document(doc, id)` - Index a single document
- `#index_jsonl_file(source, id_field:)` - Index documents from a JSONL file or IO
- `#settings` - Get index settings
- `#update_settings(settings)` - Update settings
- `#mappings` - Get index mappings
- `#update_mappings(mappings)` - Update mappings
- `#aliases` - Get list of aliases
- `#create_alias(alias_name)` - Create a new alias
- `#analyzers` / `#all_available_analyzers` - List available analyzers
- `#analyze_text(analyzer:, text:)` - Analyze text with an analyzer
- `#analyze_text_field(field:, text:)` - Analyze text using a field's analyzer

See the [OpenSearch Index APIs documentation](https://opensearch.org/docs/latest/api-reference/index-apis/) for more details on index operations.

### OpenSearch::Sugar::Models

Manages machine learning models in OpenSearch.

**Instance Methods:**
- `#register(name:, version:, format:)` / `#deploy(...)` - Register and deploy a model
- `#list` - Get list of all models
- `#[](id_or_name)` - Find a model by ID, name, or nickname
- `#undeploy!(name_or_id)` - Undeploy a model
- `#delete!(name_or_id)` - Delete a model
- `#create_pipeline(name:, model:, description:, field_map:)` - Create an ingest pipeline
- `#delete_pipeline!(name)` - Delete an ingest pipeline

See the [OpenSearch ML Commons documentation](https://opensearch.org/docs/latest/ml-commons-plugin/index/) for more information on ML models.

## Configuration

OpenSearch::Sugar uses environment variables for configuration. Create a `.env` file or set these in your environment:

```bash
# Required
OPENSEARCH_URL=https://localhost:9200
OPENSEARCH_USER=admin
OPENSEARCH_PASSWORD=your_password

# Optional (for initial setup)
OPENSEARCH_INITIAL_ADMIN_PASSWORD=admin
```

Default values:
- **Host**: `ENV['OPENSEARCH_URL']` or `https://localhost:9000`
- **User**: `ENV['OPENSEARCH_USER']` or `admin`
- **Password**: `ENV['OPENSEARCH_PASSWORD']` or `ENV['OPENSEARCH_INITIAL_ADMIN_PASSWORD']`
- **Retry on failure**: `5`
- **Request timeout**: `5` seconds
- **Log**: `true`
- **Trace**: `false`
- **SSL verification**: `false` (disable for development)

## Understanding OpenSearch::Sugar (Explanation)

### Design Philosophy

OpenSearch::Sugar is designed around these principles:

1. **Convention over Configuration** - Sensible defaults that work out of the box
2. **Progressive Disclosure** - Simple things are simple, complex things are possible
3. **Full Delegation** - Never hide the underlying client; sugar is optional

### Architecture

The gem uses Ruby's `SimpleDelegator` to wrap the official OpenSearch client. This means:

- You get all the methods of `OpenSearch::Client` automatically
- Sugar methods are added on top for convenience
- You can always drop down to the raw client when needed
- No functionality is hidden or restricted

### When to Use What

**Use OpenSearch::Sugar when:**
- Creating and managing indexes
- Working with settings and mappings
- Managing ML models
- Performing common index operations
- You want cleaner, more Ruby-like syntax

**Use the raw client when:**
- Performing complex queries
- You need fine-grained control
- Working with less common OpenSearch features
- Following existing opensearch-ruby examples

## Documentation

Complete documentation is available in the `docs/` directory, organized following the [Diátaxis Framework](https://diataxis.fr/):

- **[Tutorial](docs/TUTORIAL.md)** - Step-by-step guide to building your first OpenSearch application
- **[How-to Guides](docs/HOWTO.md)** - Practical recipes for solving specific problems
- **[API Reference](docs/REFERENCE.md)** - Complete technical reference for all classes and methods
- **[Explanation](docs/EXPLANATION.md)** - Conceptual discussions and design decisions

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt.

### Running Tests

Tests are integration tests that require a live OpenSearch node. Start one with Docker, then run the suite:

```bash
# Start OpenSearch
docker compose up -d

# Run the test suite
bundle exec rspec

# Run only ML model specs (slow; require the ML Commons plugin)
bundle exec rspec --tag models
```

### Debugging: enabling HTTP request logging

By default, the test client suppresses OpenSearch HTTP logs to keep output readable.
Set `OPENSEARCH_LOG=true` to restore full request/response logging:

```bash
OPENSEARCH_LOG=true bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/billdueber/opensearch-sugar.

1. Fork the repository
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

This gem is available as open source under the terms of the MIT License.

## Resources

- [OpenSearch Documentation](https://opensearch.org/docs/latest/)
- [OpenSearch Ruby Client](https://github.com/opensearch-project/opensearch-ruby)
- [OpenSearch API Reference](https://opensearch.org/docs/latest/api-reference/)
- [OpenSearch ML Commons](https://opensearch.org/docs/latest/ml-commons-plugin/index/)
- [OpenSearch Index APIs](https://opensearch.org/docs/latest/api-reference/index-apis/)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.

