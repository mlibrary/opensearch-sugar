# API Reference

Complete reference for the opensearch-sugar public API.

---

## `OpenSearch::Sugar::Client`

A `SimpleDelegator` wrapper around `OpenSearch::Client` that adds index management
helpers and object-oriented access to indexes and ML models.

All methods of the underlying `OpenSearch::Client` are available directly — search,
bulk, indices, cluster, and so on. Sugar-specific methods are documented below.

### Constructor

```ruby
OpenSearch::Sugar::Client.new(host: url, **kwargs)
```

**Keyword arguments**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `host` | String | `OPENSEARCH_URL` → `OPENSEARCH_HOST` → `"https://localhost:9000"` | Cluster base URL |
| `**kwargs` | Hash | — | Forwarded to `OpenSearch::Client.new` |

**Environment variable fallbacks** (all optional)

| Variable | Used for |
|----------|----------|
| `OPENSEARCH_URL` | `host` |
| `OPENSEARCH_HOST` | `host` (lower priority) |
| `OPENSEARCH_USER` | HTTP basic auth user (default: `"admin"`) |
| `OPENSEARCH_PASSWORD` | HTTP basic auth password |
| `OPENSEARCH_INITIAL_ADMIN_PASSWORD` | HTTP basic auth password (lower priority) |

**Default connection options applied automatically**

- `retry_on_failure: 5`
- `request_timeout: 5` seconds
- `log: true`
- `transport_options: { ssl: { verify: false } }`

Explicit `kwargs` take precedence over these defaults.

**Example**

```ruby
client = OpenSearch::Sugar::Client.new
client = OpenSearch::Sugar::Client.new(host: "https://search.example.com:9200")
client = OpenSearch::Sugar::Client.new(host: "https://localhost:9200", log: false)
```

---

### `Client#[]`

```ruby
client[index_name] → OpenSearch::Sugar::Index
```

Opens an existing index by name.

**Raises** `ArgumentError` if the index does not exist.

```ruby
index = client["products"]
```

---

### `Client#open_or_create_index`

```ruby
client.open_or_create_index(index_name) → OpenSearch::Sugar::Index
```

Opens the index if it exists; creates it (with KNN enabled) if it does not.

```ruby
index = client.open_or_create_index("products")
```

---

### `Client#has_index?`

```ruby
client.has_index?(name) → Boolean
```

Returns `true` if the named index exists in the cluster.

```ruby
client.has_index?("products")  #=> true
```

---

### `Client#index_names`

```ruby
client.index_names → Array<String>
```

Returns the names of all user-created indexes. System indexes (names beginning with `.`) are excluded.

```ruby
client.index_names  #=> ["products", "orders"]
```

---

### `Client#delete_index!`

```ruby
client.delete_index!(index_name) → Hash
```

Permanently deletes the named index.

**Raises** `OpenSearch::Transport::Transport::Errors::NotFound` if the index does not exist.

```ruby
client.delete_index!("products")
```

---

### `Client#update_settings`

```ruby
client.update_settings(settings, index_name) → Hash
```

Applies settings to an existing index. Automatically closes the index, applies the
settings, then reopens it.

`settings` may include or omit a top-level `:settings` key.

**Raises** `OpenSearch::Sugar::Error` if the update fails (the index is reopened before raising).

```ruby
client.update_settings(
  { settings: { analysis: { analyzer: { my: { type: "standard" } } } } },
  "products"
)
```

---

### `Client#update_mappings`

```ruby
client.update_mappings(mappings, index_name) → Hash
```

Applies field mappings to an existing index. Automatically closes the index, applies
the mappings, then reopens it.

`mappings` may include or omit a top-level `:mappings` key.

**Raises** `OpenSearch::Sugar::Error` if the update fails (the index is reopened before raising).

```ruby
client.update_mappings(
  { mappings: { properties: { title: { type: "text" } } } },
  "products"
)
```

---

### `Client#set_log_level`

```ruby
client.set_log_level(logger: "logger._root", level: "warn") → Hash
```

Writes a persistent cluster setting that controls the log level of the named logger.
The change survives cluster restarts.

**Parameters**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `logger` | String | `"logger._root"` | Logger name as understood by OpenSearch |
| `level` | String | `"warn"` | One of `"trace"`, `"debug"`, `"info"`, `"warn"`, `"error"` |

```ruby
client.set_log_level(level: "error")
client.set_log_level(logger: "logger.org.opensearch.discovery", level: "debug")
```

---

### `Client#models`

```ruby
client.models → OpenSearch::Sugar::Models
```

Returns the `Models` instance for this client. See [Models](#opensearchsugarmodels).

---

### `Client#raw_client`

```ruby
client.raw_client → OpenSearch::Client
```

Returns the unwrapped underlying `OpenSearch::Client` instance.

---

## `OpenSearch::Sugar::Index`

Represents a single OpenSearch index. Do not call `new` directly — obtain instances
via `Client#[]`, `Client#open_or_create_index`, `Index.open`, or `Index.create`.

---

### `Index.open` (class method)

```ruby
OpenSearch::Sugar::Index.open(client:, name:) → Index
```

Opens an existing index.

**Raises** `ArgumentError` if the index does not exist.

```ruby
index = OpenSearch::Sugar::Index.open(client: client, name: "products")
```

---

### `Index.create` (class method)

```ruby
OpenSearch::Sugar::Index.create(client:, name:, knn: true) → Index
```

Creates a new index.

**Parameters**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `client` | Client | — | Required |
| `name` | String | — | Required |
| `knn` | Boolean | `true` | Enable k-nearest-neighbor vector search on this index |

**Raises** `ArgumentError` if an index with the given name already exists.

```ruby
index = OpenSearch::Sugar::Index.create(client: client, name: "products", knn: false)
```

---

### `Index#name`

```ruby
index.name → String
```

The name of this index.

---

### `Index#count`

```ruby
index.count → Integer
```

Returns the number of documents in the index.

```ruby
index.count  #=> 1500
```

---

### `Index#refresh`

```ruby
index.refresh → Hash
```

Forces a refresh, making all recently indexed documents immediately visible to search
queries. Use after `index_document` or `index_jsonl_file` in tests and scripts where
you query immediately after indexing.

---

### `Index#index_document`

```ruby
index.index_document(doc, id) → Hash
```

Indexes a single document. Issues one HTTP request per call — not suitable for large
batches. For bulk loading use the raw `client.bulk` API.

**Parameters**

| Name | Type | Description |
|------|------|-------------|
| `doc` | Hash | Document body |
| `id` | String | Document ID (`_id` in OpenSearch) |

```ruby
index.index_document({ title: "Dune", author: "Frank Herbert" }, "isbn-0441013597")
```

---

### `Index#index_jsonl_file`

```ruby
index.index_jsonl_file(source, id_field:) → void
```

Indexes all documents from a JSONL (newline-delimited JSON) source. Each line must be
a valid JSON object. The value of `id_field` in each document is used as `_id`.

`source` may be a file path `String` or any IO-like object (e.g. `File`, `StringIO`).

Issues one HTTP request per line — not suitable for very large files. For bulk loading
use the raw `client.bulk` API.

**Raises** `ArgumentError` if a line does not contain the specified `id_field`.

```ruby
index.index_jsonl_file("/data/products.jsonl", id_field: :sku)
index.index_jsonl_file(StringIO.new(jsonl_string), id_field: :id)
```

---

### `Index#delete_by_id`

```ruby
index.delete_by_id(id) → Hash
```

Deletes the document with the given ID.

**Raises** `ArgumentError` if `id` is `nil` or empty.

```ruby
index.delete_by_id("isbn-0441013597")
```

---

### `Index#clear!`

```ruby
index.clear! → Integer
```

Deletes all documents from the index using `delete_by_query`. Returns the number of
documents deleted. The index itself is preserved.

```ruby
deleted = index.clear!  #=> 1500
```

---

### `Index#delete!`

```ruby
index.delete! → Hash
```

Permanently deletes the entire index and all its documents from the cluster.

```ruby
index.delete!
```

---

### `Index#settings`

```ruby
index.settings → Hash
```

Returns the current settings for this index, keyed by index name.

```ruby
index.settings
#=> { "products" => { "settings" => { "index" => { "number_of_shards" => "1", ... } } } }
```

---

### `Index#update_settings`

```ruby
index.update_settings(settings) → Hash
```

Applies new settings. Delegates to `Client#update_settings`. Accepts a hash with or
without a top-level `:settings` key.

Automatically closes the index, applies settings, and reopens it.

**Raises** `OpenSearch::Sugar::Error` on failure.

---

### `Index#mappings`

```ruby
index.mappings → Hash
```

Returns the current field mappings for this index, keyed by index name.

```ruby
index.mappings
#=> { "products" => { "mappings" => { "properties" => { "title" => { "type" => "text" } } } } }
```

---

### `Index#update_mappings`

```ruby
index.update_mappings(mappings) → Hash
```

Applies new field mappings. Delegates to `Client#update_mappings`. Accepts a hash with
or without a top-level `:mappings` key.

Automatically closes the index, applies mappings, and reopens it.

**Raises** `OpenSearch::Sugar::Error` on failure.

---

### `Index#aliases`

```ruby
index.aliases → Array<String>
```

Returns the alias names for this index. Returns an empty array if no aliases exist.

```ruby
index.aliases  #=> ["products_current", "products_v2"]
```

---

### `Index#create_alias`

```ruby
index.create_alias(alias_name) → Array<String>
```

Adds an alias to this index. Returns the complete updated list of aliases.

**Raises** `OpenSearch::Transport::Transport::Errors::BadRequest` if the alias already
exists on a different index.

```ruby
index.create_alias("products_current")  #=> ["products_current"]
```

---

### `Index#analyzers` / `Index#all_available_analyzers`

```ruby
index.analyzers → Array<String>
```

Returns the names of all analyzers available for this index: those defined in the
index's own settings plus those defined at the cluster level. `analyzers` is an alias
for `all_available_analyzers`.

```ruby
index.analyzers  #=> ["my_english", "my_exact"]
```

---

### `Index#analyze_text`

```ruby
index.analyze_text(analyzer:, text:) → Array<String, Array<String>>
```

Returns the tokens produced by the named analyzer when applied to `text`.

When multiple tokens share a position in the token stream (e.g. from a synonym filter),
they are grouped as a nested `Array` within the outer array.

**Raises** `ArgumentError` if the analyzer is not defined on this index.

```ruby
index.analyze_text(analyzer: "my_english", text: "Running fast")
#=> ["run", "fast"]

# With synonyms at the same position:
#=> ["quick", ["fast", "rapid"], "fox"]
```

---

### `Index#analyze_text_field`

```ruby
index.analyze_text_field(field:, text:) → Array<String, Array<String>>
```

Looks up the analyzer configured for `field` in this index's mappings, then delegates
to `analyze_text`. Produces the exact tokenization applied at index time.

**Raises** `ArgumentError` if `field` does not exist in the mappings.  
**Raises** `ArgumentError` if `field` has no `analyzer` configured (e.g. `keyword` fields).

```ruby
index.analyze_text_field(field: "title", text: "Running fast")
#=> ["run", "fast"]
```

---

## `OpenSearch::Sugar::Models`

Manages ML models via the OpenSearch ML Commons plugin. Access via `client.models`.

---

### `Models#register` / `Models#deploy`

```ruby
client.models.register(name:, version:, format: "TORCH_SCRIPT") → ML_INFO | nil
```

Registers and deploys a pre-trained model. Idempotent — returns the existing model if
one matching `name` is already registered.

Polls the task status every 5 seconds until deployment completes or fails.

**Parameters**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | String | — | Model name (e.g. `"all-MiniLM-L6-v2"`) |
| `version` | String | — | Version string (e.g. `"1.0.0"`) |
| `format` | String | `"TORCH_SCRIPT"` | Model format |

**Returns** an `ML_INFO` struct, or `nil` if the lookup after registration fails.

**Raises** `RuntimeError` if the registration task reports a `FAILED` state.

`deploy` is an alias for `register`.

```ruby
model = client.models.register(name: "all-MiniLM-L6-v2", version: "1.0.0")
puts model.id
```

---

### `Models#[]`

```ruby
client.models[id_or_name] → ML_INFO | nil
```

Looks up a deployed model by exact name, exact ID, or case-insensitive partial name.
When multiple partial matches exist, returns the one with the highest version.

Returns `nil` if no match is found.

```ruby
client.models["all-MiniLM-L6-v2"]   # exact name
client.models["abc123xyz"]           # exact ID
client.models["MiniLM"]             # partial, case-insensitive
```

---

### `Models#list`

```ruby
client.models.list → Array<ML_INFO>
```

Returns all deployed models as an array of `ML_INFO` structs.

```ruby
client.models.list.each { |m| puts "#{m.name} v#{m.version} (#{m.id})" }
```

---

### `Models#raw_list`

```ruby
client.models.raw_list → Hash
```

Returns the raw OpenSearch response from the ML models search endpoint. Prefer `list`
or `[]` for normal use.

---

### `Models#undeploy!`

```ruby
client.models.undeploy!(name_or_id) → Hash
```

Unloads the model from cluster memory without deleting its registration.

**Raises** `NoMethodError` if no model matching `name_or_id` is found.

```ruby
client.models.undeploy!("all-MiniLM-L6-v2")
```

---

### `Models#delete!`

```ruby
client.models.delete!(name_or_id) → Hash
```

Undeploys and permanently deletes the model.

**Raises** `NoMethodError` if no model matching `name_or_id` is found.

```ruby
client.models.delete!("all-MiniLM-L6-v2")
```

---

### `Models#create_pipeline`

```ruby
client.models.create_pipeline(name:, model:, description:, field_map:) → Hash
```

Creates a text-embedding ingest pipeline backed by a deployed ML model. Uses the
ML Commons `text_embedding` processor plus `copy` processors to move the resulting
`.knn` vectors to the intended target fields.

**Parameters**

| Name | Type | Description |
|------|------|-------------|
| `name` | String | Pipeline name |
| `model` | String | Model name, ID, or partial name accepted by `#[]` |
| `description` | String | Human-readable description |
| `field_map` | Hash{String => String} | Source text field → target vector field |

**Raises** `RuntimeError` if no model matching `model` is found.

```ruby
client.models.create_pipeline(
  name: "book-embeddings",
  model: "all-MiniLM-L6-v2",
  description: "Generate title embeddings",
  field_map: { "title" => "title_embedding" }
)
```

---

### `Models#delete_pipeline!`

```ruby
client.models.delete_pipeline!(pipeline_name) → Hash
```

Deletes an ingest pipeline by name.

```ruby
client.models.delete_pipeline!("book-embeddings")
```

---

## `OpenSearch::Sugar::Models::ML_INFO`

A `Struct` with three read-only members representing a deployed ML model.

| Member | Type | Description |
|--------|------|-------------|
| `name` | String | Model name as registered |
| `version` | String | Version string |
| `id` | String | Internal OpenSearch model ID used in API calls |

---

## Errors

| Class | Superclass | When raised |
|-------|-----------|-------------|
| `OpenSearch::Sugar::Error` | `StandardError` | Settings or mappings update fails |
| `ArgumentError` | `StandardError` | Invalid argument (missing index, bad analyzer, nil ID, etc.) |
| `OpenSearch::Transport::Transport::Errors::NotFound` | — | Index not found on `delete_index!` |
| `OpenSearch::Transport::Transport::Errors::BadRequest` | — | Invalid request to OpenSearch (e.g. duplicate alias) |
| `RuntimeError` | `StandardError` | ML model registration fails or model not found |
