# How-to Guides

Practical recipes for common tasks with opensearch-sugar. If you are just getting
started, see the [Tutorial](TUTORIAL.md) first.

---

## How to connect with explicit credentials

This guide shows you how to connect when you need to specify the host or credentials
directly rather than relying on environment variables.

```ruby
require "opensearch/sugar"

client = OpenSearch::Sugar::Client.new(
  host: "https://search.example.com:9200",
  user: "myuser",
  password: "mypassword"
)
```

To override transport options (timeouts, SSL):

```ruby
client = OpenSearch::Sugar::Client.new(
  host: "https://localhost:9200",
  retry_on_failure: 3,
  request_timeout: 10,
  transport_options: {
    ssl: {
      verify: true,
      ca_file: "/path/to/ca.pem"
    }
  }
)
```

For local development with a self-signed certificate, SSL verification is disabled
by default. Do not disable it in production.

### See also

- [Reference: Client constructor](REFERENCE.md#constructor)

---

## How to access the raw OpenSearch client

This guide shows you how to call opensearch-ruby methods that opensearch-sugar does
not wrap directly.

`OpenSearch::Sugar::Client` is a `SimpleDelegator` — every method not defined by
Sugar is forwarded automatically to the underlying `OpenSearch::Client`. You do not
need `raw_client` for most calls:

```ruby
# These all work directly on the Sugar client:
client.cluster.health
client.indices.get_alias(index: "products")
client.search(index: "products", body: { query: { match_all: {} } })
```

If you need the unwrapped client explicitly:

```ruby
raw = client.raw_client
raw.cluster.health
```

### See also

- [Reference: Client#raw_client](REFERENCE.md#clientraw_client)

---

## How to manage indexes

### Create an index

```ruby
# KNN (vector search) enabled — the default
index = OpenSearch::Sugar::Index.create(client: client, name: "products")

# Without KNN
index = OpenSearch::Sugar::Index.create(client: client, name: "products", knn: false)
```

Raises `ArgumentError` if the index already exists. Use `open_or_create_index` for
idempotent setup scripts.

### Open an existing index

```ruby
index = client["products"]
# equivalent to:
index = OpenSearch::Sugar::Index.open(client: client, name: "products")
```

Raises `ArgumentError` if the index does not exist.

### Open or create (idempotent)

```ruby
index = client.open_or_create_index("products")
```

### Check existence

```ruby
client.has_index?("products")  #=> true or false
```

### List all user indexes

```ruby
client.index_names  #=> ["products", "orders"]
```

### Delete an index

```ruby
client.delete_index!("products")
# or, if you have an Index object:
index.delete!
```

Both permanently delete the index and all its documents.

### Count documents

```ruby
index.count  #=> 42
```

### See also

- [Reference: Index management methods](REFERENCE.md#opensearchsugarclient)

---

## How to work with documents

### Index a single document

```ruby
index.index_document({ title: "Dune", author: "Frank Herbert" }, "isbn-0441013597")
```

For auto-generated IDs, use the raw client:

```ruby
response = client.index(index: "products", body: { title: "Dune" })
puts response["_id"]
```

### Get a document by ID

```ruby
response = client.get(index: "products", id: "isbn-0441013597")
document = response["_source"]
```

### Update a document

Partial update (merge fields):

```ruby
client.update(
  index: "products",
  id: "isbn-0441013597",
  body: { doc: { price: 12.99 } }
)
```

Full replacement:

```ruby
client.index(index: "products", id: "isbn-0441013597", body: { title: "Dune", price: 12.99 })
```

### Delete a document by ID

```ruby
index.delete_by_id("isbn-0441013597")
```

### Delete all documents (keep index)

```ruby
deleted = index.clear!
puts "Deleted #{deleted} documents"
```

### Bulk index documents

For large datasets, use the raw `client.bulk` API instead of `index_document`:

```ruby
operations = []
documents.each do |doc|
  operations << { index: { _index: "products", _id: doc[:id] } }
  operations << doc
end

response = client.bulk(body: operations)

if response["errors"]
  response["items"].each do |item|
    if (err = item.dig("index", "error"))
      puts "Error on #{item["index"]["_id"]}: #{err["reason"]}"
    end
  end
end
```

### Load documents from a JSONL file

```ruby
index.index_jsonl_file("/data/products.jsonl", id_field: :sku)
```

### Make documents immediately searchable

After indexing, call `refresh` before querying in scripts and tests:

```ruby
index.refresh
```

### See also

- [Reference: Index document methods](REFERENCE.md#indexindex_document)

---

## How to search

opensearch-sugar delegates `search` and all other query methods to the underlying
client. Use them directly:

### Full-text search

```ruby
response = client.search(
  index: "products",
  body: {
    query: {
      match: { title: "dune" }
    }
  }
)

response["hits"]["hits"].each do |hit|
  puts "#{hit["_source"]["title"]} (score: #{hit["_score"]})"
end
```

### Multi-field search with boosting

```ruby
client.search(
  index: "products",
  body: {
    query: {
      multi_match: {
        query: "science fiction",
        fields: ["title^3", "description^2", "categories"],
        type: "best_fields"
      }
    }
  }
)
```

`^3` means 3× weight for that field.

### Aggregations

```ruby
response = client.search(
  index: "products",
  body: {
    size: 0,
    aggs: {
      by_category: {
        terms: { field: "category", size: 10 }
      }
    }
  }
)

response["aggregations"]["by_category"]["buckets"].each do |bucket|
  puts "#{bucket["key"]}: #{bucket["doc_count"]}"
end
```

### See also

- [OpenSearch Query DSL](https://opensearch.org/docs/latest/query-dsl/)

---

## How to use an embedding pipeline when indexing

Once you have created an ingest pipeline (see
[How to deploy and use ML models](#how-to-deploy-and-use-ml-models)), pass its name
via the `pipeline:` parameter when indexing:

```ruby
client.index(
  index: "products",
  pipeline: "book-embeddings",
  body: {
    title: "Dune",
    description: "A science fiction epic set on the desert planet Arrakis."
  }
)
```

OpenSearch runs the pipeline automatically. The `title_embedding` (or whatever target
field you configured in `field_map`) is populated before the document is stored.

This also works with bulk operations:

```ruby
client.bulk(
  body: operations,
  pipeline: "book-embeddings"
)
```

### See also

- [How to deploy and use ML models](#how-to-deploy-and-use-ml-models)
- [OpenSearch ingest pipelines](https://opensearch.org/docs/latest/api-reference/ingest-apis/index/)

---

## How to handle errors

### Index not found

```ruby
begin
  index = client["nonexistent"]
rescue ArgumentError => e
  puts e.message
  index = client.open_or_create_index("nonexistent")
end
```

### Connection failure

```ruby
begin
  client.ping
rescue OpenSearch::Transport::Transport::Error => e
  puts "Could not reach cluster: #{e.message}"
end
```

### Bulk operation partial failures

`client.bulk` does not raise on partial failures — check `response["errors"]`:

```ruby
response = client.bulk(body: operations)
if response["errors"]
  failed = response["items"].select { |item| item.dig("index", "error") }
  failed.each do |item|
    puts "Failed #{item["index"]["_id"]}: #{item.dig("index", "error", "reason")}"
  end
end
```

### Analyzer not found

```ruby
begin
  tokens = index.test_analyzer_by_name(analyzer: "missing", text: "hello")
rescue ArgumentError => e
  puts e.message
  puts "Available: #{index.analyzers.join(", ")}"
end
```

### Retrying with exponential backoff

The client retries automatically (`retry_on_failure: 5` by default). For application-level
retry logic with backoff:

```ruby
retries = 0
begin
  client.index(index: "products", id: "1", body: { title: "Dune" })
rescue OpenSearch::Transport::Transport::Error => e
  retries += 1
  raise if retries >= 3
  sleep(2**retries)
  retry
end
```

### See also

- [Reference: Errors](REFERENCE.md#errors)

---

## How to configure custom analyzers

This guide shows you how to define custom analyzers on an index when you need
non-default tokenization or filtering behaviour.

### Before you start

- A running OpenSearch cluster
- An existing index (or use `open_or_create_index`)
- Settings must be applied **before** you index documents, or before you remap fields that use those analyzers

### Steps

#### Define the analyzer in settings

```ruby
index.update_settings(
  settings: {
    analysis: {
      filter: {
        my_stop: {
          type: "stop",
          stopwords: ["the", "a", "an"]
        },
        my_stem: {
          type: "stemmer",
          language: "english"
        }
      },
      analyzer: {
        my_english: {
          type: "custom",
          tokenizer: "standard",
          filter: ["lowercase", "my_stop", "my_stem"]
        }
      }
    }
  }
)
```

`update_settings` automatically closes the index, applies the settings, and reopens
it. Do not close the index yourself.

#### Verify the analyzer is registered

```ruby
puts index.analyzers
# => ["my_english"]
```

#### Apply the analyzer to a field

```ruby
index.update_mappings(
  mappings: {
    properties: {
      body: { type: "text", analyzer: "my_english" }
    }
  }
)
```

### Troubleshooting

**`ArgumentError: Analyzer 'x' does not exist in index 'y'`**
The analyzer was not registered before calling `test_analyzer_by_name`. Run `update_settings`
first, then verify with `index.analyzers`.

**Settings update fails with a 400 error**
Some settings (e.g. `number_of_shards`) cannot be changed after creation. Analysis
settings can always be updated.

### See also

- [How to debug text analysis](#how-to-debug-text-analysis)
- [How to define field mappings](#how-to-define-field-mappings)
- [OpenSearch analysis reference](https://opensearch.org/docs/latest/analyzers/)

---

## How to define field mappings

This guide shows you how to define the field types and analyzer assignments for an index.

### Before you start

- Custom analyzers referenced in the mappings must already be registered (see
  [How to configure custom analyzers](#how-to-configure-custom-analyzers))
- Mappings can be added to after creation, but existing field types cannot be changed

### Steps

#### Apply mappings

```ruby
index.update_mappings(
  mappings: {
    properties: {
      title:       { type: "text",    analyzer: "my_english" },
      author:      { type: "text" },
      isbn:        { type: "keyword" },
      published:   { type: "date" },
      page_count:  { type: "integer" },
      categories:  { type: "keyword" },
      embedding:   { type: "knn_vector", dimension: 384 }
    }
  }
)
```

#### Inspect current mappings

```ruby
pp index.mappings
```

The response is keyed by index name:

```ruby
{
  "books" => {
    "mappings" => {
      "properties" => {
        "title" => { "type" => "text", "analyzer" => "my_english" },
        # ...
      }
    }
  }
}
```

### Troubleshooting

**Mapping conflict error on update**
You cannot change an existing field's type. Create a new index with the correct mapping
and reindex your data.

**Field not found when calling `test_analyzer_by_fieldname`**
The field must exist in the mappings and must have an `analyzer` key. `keyword` fields
have no analyzer — use `test_analyzer_by_name` with an explicit analyzer name instead.

### See also

- [Reference: Index#update_mappings](REFERENCE.md#indexupdate_mappings)
- [OpenSearch field types](https://opensearch.org/docs/latest/field-types/)

---

## How to create and use aliases

This guide shows you how to add an alias to an index and use it for reads and writes.

### When to use this guide

Use aliases when you want a stable name for an index that may be replaced (e.g. during
a reindex operation), or when you want one name to point to multiple indexes.

### Steps

#### Add an alias

```ruby
index.create_alias("products_current")
# => ["products_current"]
```

#### Verify aliases

```ruby
puts index.aliases
# => ["products_current"]
```

#### Use the alias to access the index

```ruby
current = client["products_current"]
puts current.count
```

#### Swap an alias between two indexes (blue/green reindex)

This uses the raw client for the atomic swap, which opensearch-sugar delegates through:

```ruby
client.indices.update_aliases(
  body: {
    actions: [
      { remove: { index: "products_v1", alias: "products_current" } },
      { add:    { index: "products_v2", alias: "products_current" } }
    ]
  }
)
```

### Troubleshooting

**`BadRequest` when creating alias**
An alias with the same name already exists on a different index. Either remove it from
the other index first, or use `update_aliases` for an atomic swap.

### See also

- [Reference: Index#create_alias](REFERENCE.md#indexcreate_alias)
- [OpenSearch aliases](https://opensearch.org/docs/latest/opensearch/index-alias/)

---

## How to deploy and use ML models

This guide shows you how to register a pre-trained sentence-embedding model and create
an ingest pipeline that generates embeddings automatically at index time.

### Before you start

- The ML Commons plugin must be enabled on your cluster
- The cluster must have enough memory to hold the model (typically 1–2 GB)
- For local development, start OpenSearch with `plugins.ml_commons.only_run_on_ml_node: false`

### Steps

#### Register and deploy the model

```ruby
model = client.models.register(
  name: "all-MiniLM-L6-v2",
  version: "1.0.0",
  format: "TORCH_SCRIPT"
)
puts "Model ID: #{model.id}"
```

`register` is idempotent — calling it again returns the existing model without
re-registering. It polls until deployment completes (about 30–120 seconds first time).

#### List deployed models

```ruby
client.models.list.each do |m|
  puts "#{m.name} v#{m.version} (#{m.id})"
end
```

#### Look up a model by name or partial name

```ruby
m = client.models["MiniLM"]       # partial, case-insensitive
m = client.models["all-MiniLM-L6-v2"]  # exact name
m = client.models["abc123xyz"]    # by ID
```

#### Create an embedding ingest pipeline

```ruby
client.models.create_pipeline(
  name: "book-embeddings",
  model: "all-MiniLM-L6-v2",
  description: "Generate title embeddings for semantic search",
  field_map: { "title" => "title_embedding" }
)
```

`field_map` maps source text fields to target vector fields. The pipeline runs
automatically when documents are indexed.

#### Delete a model

```ruby
client.models.delete!("all-MiniLM-L6-v2")  # undeploys then deletes
client.models.undeploy!("all-MiniLM-L6-v2") # unloads from memory only
```

#### Delete a pipeline

```ruby
client.models.delete_pipeline!("book-embeddings")
```

### Troubleshooting

**`register` raises with a FAILED state**
Check cluster logs for memory or plugin errors. Make sure `only_run_on_ml_node` is
configured appropriately.

**`NoMethodError` from `undeploy!` or `delete!`**
The model name or ID was not found. Use `client.models.list` to confirm the exact name.

### See also

- [Reference: Models](REFERENCE.md#models)
- [OpenSearch ML Commons plugin](https://opensearch.org/docs/latest/ml-commons-plugin/)
- [OpenSearch semantic search](https://opensearch.org/docs/latest/ml-commons-plugin/semantic-search/)

---

## How to debug text analysis

This guide shows you how to inspect the tokens that OpenSearch produces from a string,
so you can diagnose unexpected search behaviour.

### When to use this guide

Use this when searches are returning unexpected results and you suspect the issue is in
how text is being tokenized — for example, stemming producing wrong roots, or stop words
being removed unexpectedly.

### Steps

#### List analyzers defined on the index

```ruby
puts index.analyzers
# => ["my_english", "my_exact"]
```

#### Inspect tokens from a named analyzer

```ruby
tokens = index.test_analyzer_by_name(
  analyzer: "my_english",
  text: "The Running Foxes jumped quickly"
)
puts tokens.inspect
# => ["run", "fox", "jump", "quick"]
```

#### Inspect tokens using a field's configured analyzer

```ruby
tokens = index.test_analyzer_by_fieldname(
  field: "title",
  text: "The Running Foxes jumped quickly"
)
puts tokens.inspect
```

This uses whatever analyzer is configured on the `title` field's mapping, so the
results exactly match what OpenSearch stores at index time.

#### Compare index-time and search-time analyzers

If a field uses different analyzers for indexing and querying (`analyzer` vs
`search_analyzer`), call `test_analyzer_by_name` explicitly for each:

```ruby
index_tokens  = index.test_analyzer_by_name(analyzer: "my_index_analyzer",  text: query)
search_tokens = index.test_analyzer_by_name(analyzer: "my_search_analyzer", text: query)
puts "Indexed as: #{index_tokens}"
puts "Queried as: #{search_tokens}"
```

Mismatches here are a common cause of zero-result queries.

#### Understand grouped tokens

When multiple tokens share a position in the token stream (e.g. from a synonym filter),
they are returned as a nested array:

```ruby
# => ["quick", ["fast", "rapid"], "fox"]
```

Both `"fast"` and `"rapid"` occupy the same position as `"quick"` in this example.

### Troubleshooting

**`ArgumentError: Analyzer 'x' does not exist`**
The analyzer is not defined on this index. Use `index.analyzers` to see what is
available. Built-in analyzers (e.g. `standard`, `english`) cannot be referenced with
`test_analyzer_by_name` — use the raw client's `indices.analyze` API directly for those.

**`ArgumentError: No analyzer specified for field 'x'`**
The field exists but has no `analyzer` key in its mapping (e.g. it is a `keyword`
field). Use `test_analyzer_by_name` with an explicit analyzer name instead.

### See also

- [Reference: Index#test_analyzer_by_name](REFERENCE.md#indextest_analyzer_by_name)
- [Reference: Index#test_analyzer_by_fieldname](REFERENCE.md#indextest_analyzer_by_fieldname)
- [OpenSearch text analysis](https://opensearch.org/docs/latest/analyzers/)
