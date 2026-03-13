# API Reference

*(Documentation written by GitHub Copilot, powered by Claude Sonnet 4.5)*

Complete technical reference for all classes, methods, and interfaces in OpenSearch::Sugar.

## Table of Contents

- [Module: OpenSearch::Sugar](#module-opensearchsugar)
- [Class: OpenSearch::Sugar::Client](#class-opensearchsugarclient)
- [Class: OpenSearch::Sugar::Index](#class-opensearchsugarindex)
- [Class: OpenSearch::Sugar::Models](#class-opensearchsugarmodels)
- [Error Classes](#error-classes)

---

## Module: OpenSearch::Sugar

The main namespace module for the OpenSearch::Sugar gem.

### Module Methods

#### `OpenSearch::Sugar.client(**kwargs)`

Creates a new OpenSearch::Sugar::Client instance.

**Parameters:**
- `**kwargs` (Hash) - Connection parameters passed to Client.new

**Returns:**
- (OpenSearch::Sugar::Client) - A new client instance

**Example:**
```ruby
client = OpenSearch::Sugar.client(
  host: 'https://localhost:9200',
  user: 'admin',
  password: 'admin'
)
```

#### `OpenSearch::Sugar.new(**kwargs)`

Alias for `OpenSearch::Sugar.client`. Creates a new client instance.

**Parameters:**
- `**kwargs` (Hash) - Connection parameters

**Returns:**
- (OpenSearch::Sugar::Client) - A new client instance

**Example:**
```ruby
client = OpenSearch::Sugar.new
```

---

## Class: OpenSearch::Sugar::Client

The main client class that wraps the OpenSearch::Client. Inherits from SimpleDelegator, providing access to all OpenSearch::Client methods while adding convenient sugar methods.

**Inherits:** SimpleDelegator

**See Also:**
- [OpenSearch Ruby Client Documentation](https://opensearch.org/docs/latest/clients/ruby/)
- [OpenSearch API Reference](https://opensearch.org/docs/latest/api-reference/)

### Class Methods

#### `.raw_client(*args, **kwargs)`

Creates a new raw OpenSearch::Client instance without the sugar wrapper.

**Parameters:**
- `*args` (Array) - Positional arguments for OpenSearch::Client
- `**kwargs` (Hash) - Keyword arguments for OpenSearch::Client

**Returns:**
- (OpenSearch::Client) - A raw OpenSearch client instance

**Example:**
```ruby
raw = OpenSearch::Sugar::Client.raw_client(
  host: 'https://localhost:9200'
)
```

#### `.new(**kwargs)`

Creates a new OpenSearch::Sugar::Client instance.

**Parameters:**
- `host` (String) - OpenSearch host URL (default: `ENV['OPENSEARCH_URL']` or `ENV['OPENSEARCH_HOST']` or `'https://localhost:9000'`)
- `user` (String) - Username (default: `ENV['OPENSEARCH_USER']` or `'admin'`)
- `password` (String) - Password (default: `ENV['OPENSEARCH_PASSWORD']` or `ENV['OPENSEARCH_INITIAL_ADMIN_PASSWORD']`)
- `logger` (Logger) - Logger instance for warnings and errors (default: `Logger.new($stdout, level: Logger::WARN)`)
- `retry_on_failure` (Integer) - Number of retries (default: 5)
- `request_timeout` (Integer) - Request timeout in seconds (default: 5)
- `log` (Boolean) - Enable logging (default: true)
- `trace` (Boolean) - Enable trace logging (default: false)
- `transport_options` (Hash) - HTTP transport options including SSL settings (default: `{ssl: {verify: true}}`)
- `**kwargs` (Hash) - Additional options passed to OpenSearch::Client

**Returns:**
- (OpenSearch::Sugar::Client) - A new client instance

**Security Note:** SSL verification is **enabled by default** (`verify: true`). Only disable for local development.

**Example:**
```ruby
# With SSL verification (default, recommended)
client = OpenSearch::Sugar::Client.new(
  host: 'https://search.example.com:9200',
  user: 'myuser',
  password: 'secret',
  retry_on_failure: 3,
  request_timeout: 10,
  log: false
)

# With custom logger
require 'logger'
client = OpenSearch::Sugar::Client.new(
  logger: Logger.new('opensearch.log', level: Logger::INFO)
)

# Development only - disable SSL verification
client = OpenSearch::Sugar::Client.new(
  host: 'https://localhost:9200',
  transport_options: {
    ssl: { verify: false }  # Only for development!
  }
)
```

### Instance Attributes

#### `#raw_client`

**Type:** OpenSearch::Client (readonly)

**Description:** The underlying raw OpenSearch::Client instance.

**Example:**
```ruby
raw = client.raw_client
response = raw.cluster.health
```

#### `#models`

**Type:** OpenSearch::Sugar::Models (readonly)

**Description:** The models interface for managing ML models.

**Example:**
```ruby
models = client.models
models.list
```

#### `#logger`

**Type:** Logger (readonly)

**Description:** The logger instance used for warnings and errors.

**Example:**
```ruby
client.logger.info "Custom log message"
client.logger.level = Logger::DEBUG
```

### Instance Methods

#### `#default_args`

Returns the default connection arguments used by the client.

**Returns:**
- (Hash) - Default connection parameters

**Example:**
```ruby
defaults = client.default_args
puts defaults[:host]
# => "https://localhost:9000"
```

#### `#set_log_level(logger: 'logger._root', level: 'warn')`

Sets the logging level for OpenSearch cluster loggers.

**Parameters:**
- `logger` (String) - Logger name (default: `'logger._root'`)
- `level` (String) - Log level: `'trace'`, `'debug'`, `'info'`, `'warn'`, `'error'`, `'fatal'`

**Returns:**
- (Hash) - OpenSearch response

**See:** [OpenSearch Logging Documentation](https://opensearch.org/docs/latest/install-and-configure/configuring-opensearch/logs/)

**Example:**
```ruby
client.set_log_level(logger: 'logger._root', level: 'warn')
client.set_log_level(logger: 'index.search.slowlog', level: 'debug')
```

#### `#has_index?(name)`

Checks if an index exists in OpenSearch.

**Parameters:**
- `name` (String) - The index name to check

**Returns:**
- (Boolean) - `true` if index exists, `false` otherwise

**Example:**
```ruby
if client.has_index?('my_index')
  puts "Index exists"
end
```

#### `#index_names`

Returns a list of all index names in the cluster.

**Returns:**
- (Array<String>) - Array of index names

**Example:**
```ruby
names = client.index_names
# => ["index1", "index2", "index3"]
```

#### `#[](index_name)`

Opens an existing index by name.

**Parameters:**
- `index_name` (String) - The name of the index to open

**Returns:**
- (OpenSearch::Sugar::Index) - The index instance

**Raises:**
- (ArgumentError) - If index does not exist

**Example:**
```ruby
index = client['my_index']
```

#### `#open_or_create(index_name)`

Opens an existing index or creates it if it doesn't exist.

**Parameters:**
- `index_name` (String) - The index name

**Returns:**
- (OpenSearch::Sugar::Index) - The index instance

**Example:**
```ruby
index = client.open_or_create('my_index')
```

#### `#update_settings(settings, index_name)`

Updates settings for an index. Automatically closes and reopens the index.

**Parameters:**
- `settings` (Hash) - The settings hash
- `index_name` (String) - The name of the index to update

**Returns:**
- (void)

**Raises:**
- (OpenSearch::Transport::Transport::Error) - If the settings update fails

**Example:**
```ruby
settings = {
  settings: {
    analysis: {
      analyzer: {
        my_analyzer: {
          type: 'standard',
          stopwords: ['the', 'a']
        }
      }
    }
  }
}

begin
  client.update_settings(settings, 'my_index')
  puts "Settings updated successfully"
rescue OpenSearch::Transport::Transport::Error => e
  puts "Error: #{e.message}"
end
```

#### `#update_mappings(mappings, index_name)`

Updates mappings for an index. Automatically closes and reopens the index.

**Parameters:**
- `mappings` (Hash) - The mappings hash
- `index_name` (String) - The name of the index to update

**Returns:**
- (void)

**Raises:**
- (OpenSearch::Transport::Transport::Error) - If the mappings update fails

**Example:**
```ruby
mappings = {
  mappings: {
    properties: {
      title: { type: 'text' },
      created_at: { type: 'date' }
    }
  }
}

begin
  client.update_mappings(mappings, 'my_index')
  puts "Mappings updated successfully"
rescue OpenSearch::Transport::Transport::Error => e
  puts "Error: #{e.message}"
end
```

### Delegated Methods

Because `Client` inherits from `SimpleDelegator` and wraps `OpenSearch::Client`, all OpenSearch client methods are available:

**Index Operations:**
- `indices.create`, `indices.delete`, `indices.exists?`, `indices.refresh`
- `indices.open`, `indices.close`, `indices.get_settings`, `indices.put_settings`
- `indices.get_mapping`, `indices.put_mapping`, `indices.update_aliases`

**Document Operations:**
- `index`, `get`, `update`, `delete`, `bulk`
- `search`, `count`, `delete_by_query`, `update_by_query`

**Cluster Operations:**
- `cluster.health`, `cluster.state`, `cluster.stats`, `cluster.get_settings`

**Analysis:**
- `indices.analyze`

See the [OpenSearch Ruby Client](https://github.com/opensearch-project/opensearch-ruby) and [OpenSearch API documentation](https://opensearch.org/docs/latest/api-reference/) for complete method listings.

---

## Class: OpenSearch::Sugar::Index

Represents an OpenSearch index with convenient methods for index operations.

**See Also:**
- [OpenSearch Index APIs](https://opensearch.org/docs/latest/api-reference/index-apis/)

### Class Methods

#### `.open(client:, name:)`

Opens an existing index.

**Parameters:**
- `client` (OpenSearch::Sugar::Client) - The client instance
- `name` (String) - The index name

**Returns:**
- (OpenSearch::Sugar::Index) - The index instance

**Raises:**
- (ArgumentError) - If the index does not exist

**Example:**
```ruby
index = OpenSearch::Sugar::Index.open(
  client: client,
  name: 'my_index'
)
```

#### `.create(client:, name:, knn: true)`

Creates a new index.

**Parameters:**
- `client` (OpenSearch::Sugar::Client) - The client instance
- `name` (String) - The index name
- `knn` (Boolean) - Enable k-NN functionality (default: true)

**Returns:**
- (OpenSearch::Sugar::Index) - The newly created index instance

**Raises:**
- (ArgumentError) - If the index already exists

**Example:**
```ruby
index = OpenSearch::Sugar::Index.create(
  client: client,
  name: 'my_index',
  knn: true
)
```

### Instance Attributes

#### `#client`

**Type:** OpenSearch::Sugar::Client

**Description:** The client instance this index belongs to.

#### `#name`

**Type:** String

**Description:** The name of this index.

### Instance Methods

#### `#settings`

Gets the current settings for this index.

**Returns:**
- (Hash) - The index settings

**Example:**
```ruby
settings = index.settings
analyzer = settings.dig('my_index', 'settings', 'index', 'analysis', 'analyzer')
```

#### `#update_settings(settings)`

Updates the settings for this index.

**Parameters:**
- `settings` (Hash) - The settings to apply

**Returns:**
- (void)

**Raises:**
- (OpenSearch::Transport::Transport::Error) - If the settings update fails

**Example:**
```ruby
begin
  index.update_settings(
    settings: {
      number_of_replicas: 2,
      refresh_interval: '5s'
    }
  )
  puts "Settings updated"
rescue OpenSearch::Transport::Transport::Error => e
  puts "Error: #{e.message}"
end
```

#### `#mappings`

Gets the current mappings for this index.

**Returns:**
- (Hash) - The index mappings

**Example:**
```ruby
mappings = index.mappings
properties = mappings.dig('my_index', 'mappings', 'properties')
```

#### `#update_mappings(mappings)`

Updates the mappings for this index.

**Parameters:**
- `mappings` (Hash) - The mappings to apply

**Returns:**
- (void)

**Raises:**
- (OpenSearch::Transport::Transport::Error) - If the mappings update fails

**Example:**
```ruby
begin
  index.update_mappings(
    mappings: {
      properties: {
        title: { type: 'text' },
        tags: { type: 'keyword' }
      }
    }
  )
  puts "Mappings updated"
rescue OpenSearch::Transport::Transport::Error => e
  puts "Error: #{e.message}"
end
```

#### `#count`

Returns the number of documents in this index.

**Returns:**
- (Integer) - Document count

**Example:**
```ruby
count = index.count
puts "Total documents: #{count}"
```

#### `#delete!`

Permanently deletes this index and all its data.

**Returns:**
- (Hash) - OpenSearch response

**Warning:** This operation is irreversible!

**Example:**
```ruby
index.delete!
```

#### `#clear!`

Deletes all documents from this index using delete_by_query.

**Returns:**
- (Integer) - Number of documents deleted

**Example:**
```ruby
deleted = index.clear!
puts "Deleted #{deleted} documents"
```

#### `#delete_by_id(id)`

Deletes a single document by ID.

**Parameters:**
- `id` (String) - The document ID to delete

**Returns:**
- (Hash) - OpenSearch response

**Raises:**
- (ArgumentError) - If ID is nil or empty

**Example:**
```ruby
index.delete_by_id('doc123')
```

#### `#aliases`

Returns the list of aliases for this index.

**Returns:**
- (Array<String>) - Array of alias names

**Example:**
```ruby
aliases = index.aliases
# => ["alias1", "alias2"]
```

#### `#create_alias(alias_name)`

Creates an alias for this index.

**Parameters:**
- `alias_name` (String) - The alias name to create

**Returns:**
- (Array<String>) - Updated list of all aliases

**Example:**
```ruby
index.create_alias('my_alias')
```

#### `#all_available_analyzers` / `#analyzers`

Returns all analyzers available to this index (both index-level and cluster-level).

**Returns:**
- (Array<String>) - Array of analyzer names

**Example:**
```ruby
analyzers = index.analyzers
# => ["standard", "simple", "whitespace", "my_custom_analyzer"]
```

#### `#analyze_text(analyzer:, text:)`

Analyzes text using a specified analyzer and returns the resulting tokens.

**Parameters:**
- `analyzer` (String) - The analyzer name to use
- `text` (String) - The text to analyze

**Returns:**
- (Array<String, Array<String>>) - Array of tokens; if multiple tokens exist at the same position, they're grouped in a sub-array

**Raises:**
- (ArgumentError) - If the analyzer doesn't exist in the index

**See:** [OpenSearch Analyze API](https://opensearch.org/docs/latest/api-reference/analyze-apis/)

**Example:**
```ruby
tokens = index.analyze_text(
  analyzer: 'standard',
  text: 'The quick brown fox'
)
# => ["the", "quick", "brown", "fox"]
```

#### `#analyze_text_field(field:, text:)`

Analyzes text using the analyzer configured for a specific field.

**Parameters:**
- `field` (String) - The field name whose analyzer to use
- `text` (String) - The text to analyze

**Returns:**
- (Array<String, Array<String>>) - Array of tokens

**Raises:**
- (ArgumentError) - If the field doesn't exist or has no analyzer

**Example:**
```ruby
tokens = index.analyze_text_field(
  field: 'title',
  text: 'My Document Title'
)
```

---

## Class: OpenSearch::Sugar::Models

Manages machine learning models in OpenSearch.

**See Also:**
- [OpenSearch ML Commons Plugin](https://opensearch.org/docs/latest/ml-commons-plugin/)

### Nested Classes

#### `ML_INFO`

A Struct containing model information.

**Fields:**
- `name` (String) - Model name
- `version` (String) - Model version
- `id` (String) - Internal model ID

### Instance Methods

#### `#initialize(os)`

Creates a new Models instance.

**Parameters:**
- `os` (OpenSearch::Sugar::Client) - The client instance

**Note:** Typically accessed via `client.models`, not instantiated directly.

#### `#register(name:, version:, format: 'TORCH_SCRIPT')` / `#deploy(...)`

Registers and deploys a machine learning model. Waits for deployment to complete.

**Parameters:**
- `name` (String) - Full model name (e.g., `'huggingface/sentence-transformers/all-MiniLM-L12-v2'`)
- `version` (String) - Model version
- `format` (String) - Model format (default: `'TORCH_SCRIPT'`)

**Returns:**
- (ML_INFO) - Model information struct, or existing model if already registered

**Example:**
```ruby
model = client.models.register(
  name: 'huggingface/sentence-transformers/all-MiniLM-L12-v2',
  version: '1.0.1',
  format: 'TORCH_SCRIPT'
)

puts "Deployed: #{model.name} v#{model.version}"
```

#### `#list`

Returns a list of all registered ML models.

**Returns:**
- (Array<ML_INFO>) - Array of model information structs

**Example:**
```ruby
models = client.models.list
models.each do |model|
  puts "#{model.name} v#{model.version} (#{model.id})"
end
```

#### `#[](id_or_fullname_or_nickname)`

Finds a model by ID, exact name, or partial name match.

**Parameters:**
- `id_or_fullname_or_nickname` (String) - Model identifier

**Returns:**
- (ML_INFO, nil) - Model information or nil if not found

**Behavior:**
1. Tries exact name match first
2. Then tries ID match
3. Finally tries case-insensitive regex match on name, returning latest version

**Example:**
```ruby
# By exact name
model = client.models['huggingface/sentence-transformers/all-MiniLM-L12-v2']

# By ID
model = client.models['abc123']

# By nickname (case-insensitive, partial match)
model = client.models['minilm']  # Finds latest MiniLM model
```

#### `#raw_list`

Returns the raw OpenSearch response for model listing.

**Returns:**
- (Hash) - Raw OpenSearch response

**Example:**
```ruby
raw = client.models.raw_list
hits = raw['hits']['hits']
```

#### `#undeploy!(name_or_id)`

Undeploys a model by name or ID.

**Parameters:**
- `name_or_id` (String) - Model name or ID

**Returns:**
- (Hash) - OpenSearch response

**Example:**
```ruby
client.models.undeploy!('all-MiniLM-L12-v2')
```

#### `#delete!(name_or_id)`

Deletes a model by name or ID. Automatically undeploys first.

**Parameters:**
- `name_or_id` (String) - Model name or ID

**Returns:**
- (Hash) - OpenSearch response

**Example:**
```ruby
client.models.delete!('all-MiniLM-L12-v2')
```

#### `#create_pipeline(name:, model:, description:, field_map:)`

Creates an ingest pipeline that uses a model to generate embeddings.

**Parameters:**
- `name` (String) - Pipeline name (spaces converted to underscores)
- `model` (String) - Model name or ID
- `description` (String) - Pipeline description
- `field_map` (Hash) - Map of source field to target embedding field

**Returns:**
- (Hash) - OpenSearch response

**Example:**
```ruby
client.models.create_pipeline(
  name: 'text_embedding_pipeline',
  model: 'all-MiniLM-L12-v2',
  description: 'Generate text embeddings',
  field_map: {
    'content' => 'content_embedding',
    'title' => 'title_embedding'
  }
)

# Use the pipeline when indexing
client.index(
  index: 'my_index',
  pipeline: 'text_embedding_pipeline',
  body: {
    title: 'My Document',
    content: 'Document text here'
  }
)
```

---

## Error Classes

### `OpenSearch::Sugar::Error`

Base error class for all OpenSearch::Sugar errors.

**Inherits:** StandardError

**Example:**
```ruby
begin
  # Operation that might fail
rescue OpenSearch::Sugar::Error => e
  puts "OpenSearch::Sugar error: #{e.message}"
end
```

### ArgumentError

Ruby's standard ArgumentError is raised for invalid arguments.

**Common cases:**
- Index doesn't exist when calling `Index.open`
- Index already exists when calling `Index.create`
- Analyzer doesn't exist in `analyze_text`
- Field doesn't exist in `analyze_text_field`
- Document ID is nil/empty in `delete_by_id`

**Example:**
```ruby
begin
  index = OpenSearch::Sugar::Index.open(client: client, name: 'nonexistent')
rescue ArgumentError => e
  puts "Error: #{e.message}"
  # => "Index nonexistent not found"
end
```

### OpenSearch::Transport::Transport::Error

Errors from the underlying OpenSearch transport layer.

**Common subclasses:**
- `OpenSearch::Transport::Transport::Errors::NotFound` - Resource not found (404)
- `OpenSearch::Transport::Transport::Errors::BadRequest` - Invalid request (400)
- `OpenSearch::Transport::Transport::Errors::Unauthorized` - Authentication failed (401)
- `OpenSearch::Transport::Transport::Errors::Forbidden` - Permission denied (403)

**Example:**
```ruby
begin
  client.search(index: 'nonexistent', body: {query: {match_all: {}}})
rescue OpenSearch::Transport::Transport::Errors::NotFound => e
  puts "Index not found: #{e.message}"
rescue OpenSearch::Transport::Transport::Error => e
  puts "Transport error: #{e.message}"
end
```

---

## Type Signatures

For type checking with tools like Sorbet or Steep, see the [RBS type signatures](../sig/opensearch/sugar.rbs) in the `sig/` directory.

---

## Additional Resources

- [OpenSearch Documentation](https://opensearch.org/docs/latest/)
- [OpenSearch Ruby Client](https://github.com/opensearch-project/opensearch-ruby)
- [OpenSearch API Reference](https://opensearch.org/docs/latest/api-reference/)
- [OpenSearch ML Commons](https://opensearch.org/docs/latest/ml-commons-plugin/)
- [Tutorial](TUTORIAL.md) - Step-by-step learning guide
- [How-to Guides](HOWTO.md) - Problem-solving recipes
- [Explanation](EXPLANATION.md) - Understanding concepts

