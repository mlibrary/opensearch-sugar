# How-to Guides

*(Documentation written by GitHub Copilot, powered by Claude Sonnet 4.5)*

This document provides practical recipes for solving specific problems with OpenSearch::Sugar. Each guide is focused on accomplishing a particular task.

## Table of Contents

- [Connection and Configuration](#connection-and-configuration)
- [Index Management](#index-management)
- [Document Operations](#document-operations)
- [Search and Analysis](#search-and-analysis)
- [Settings and Mappings](#settings-and-mappings)
- [Aliases](#aliases)
- [ML Models](#ml-models)
- [Error Handling](#error-handling)

---

## Connection and Configuration

### How to Connect with Environment Variables

```ruby
# Set environment variables first:
# OPENSEARCH_URL=https://localhost:9200
# OPENSEARCH_USER=admin
# OPENSEARCH_PASSWORD=secret

require 'opensearch/sugar'

# Client automatically uses environment variables
client = OpenSearch::Sugar.new
```

### How to Connect with Explicit Credentials

```ruby
client = OpenSearch::Sugar.new(
  host: 'https://search.example.com:9200',
  user: 'myuser',
  password: 'mypassword'
)
```

### How to Configure Connection Options

```ruby
client = OpenSearch::Sugar.new(
  host: 'https://localhost:9200',
  user: 'admin',
  password: 'admin',
  retry_on_failure: 3,
  request_timeout: 10,
  log: true,
  trace: false,
  transport_options: {
    ssl: {
      verify: true,
      ca_file: '/path/to/ca.pem'
    }
  }
)
```

### How to Disable SSL Verification (Development Only)

```ruby
client = OpenSearch::Sugar.new(
  host: 'https://localhost:9200',
  transport_options: {
    ssl: { verify: false }
  }
)
```

**Warning:** Only use this in development! Production should use proper SSL.

### How to Set Cluster Log Level

```ruby
# Set all loggers to warn level
client.set_log_level(logger: 'logger._root', level: 'warn')

# Set specific logger
client.set_log_level(logger: 'index.search.slowlog', level: 'debug')
```

See [OpenSearch Logging Documentation](https://opensearch.org/docs/latest/install-and-configure/configuring-opensearch/logs/)

### How to Access the Raw Client

```ruby
# OpenSearch::Sugar::Client delegates to the raw client
# So you can call any opensearch-ruby method directly:
response = client.cluster.health

# Or access explicitly:
raw = client.raw_client
response = raw.cluster.health
```

---

## Index Management

### How to Create an Index

```ruby
# Create a new index with k-NN enabled (default)
index = OpenSearch::Sugar::Index.create(
  client: client,
  name: 'my_index',
  knn: true
)

# Create without k-NN
index = OpenSearch::Sugar::Index.create(
  client: client,
  name: 'my_index',
  knn: false
)
```

**When this fails:**
- Index already exists → Use `open_or_create_index` or delete the existing index first

### How to Open an Existing Index

```ruby
# Open an existing index
index = client['my_index']

# Or using the explicit method
index = OpenSearch::Sugar::Index.open(client: client, name: 'my_index')
```

**When this fails:**
- Index doesn't exist → Use `create` or `open_or_create_index`

### How to Open or Create an Index

```ruby
# Opens if exists, creates if doesn't
index = client.open_or_create_index('my_index')
```

**Use this when:**
- You're not sure if the index exists
- You want idempotent setup scripts

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
# Get array of index names
names = client.index_names
puts "Indexes: #{names.join(', ')}"
```

### How to Delete an Index

```ruby
index = client['my_index']
index.delete!

# Or directly
client.indices.delete(index: 'my_index')
```

**Warning:** This permanently deletes the index and all its data!

### How to Count Documents in an Index

```ruby
index = client['my_index']
count = index.count
puts "Total documents: #{count}"
```

---

## Document Operations

### How to Add a Single Document

```ruby
# Add with explicit ID
client.index(
  index: 'my_index',
  id: 'doc123',
  body: {
    title: 'My Document',
    content: 'Document content here'
  }
)

# Add with auto-generated ID
response = client.index(
  index: 'my_index',
  body: { title: 'My Document' }
)
puts "Generated ID: #{response['_id']}"
```

### How to Delete a Document by ID

```ruby
index = client['my_index']
index.delete_by_id('doc123')

# Or using raw client
client.delete(index: 'my_index', id: 'doc123')
```

### How to Delete All Documents from an Index

```ruby
index = client['my_index']
deleted_count = index.clear!
puts "Deleted #{deleted_count} documents"
```

**Note:** This keeps the index structure but removes all documents.

### How to Get a Document by ID

```ruby
# Using raw client (OpenSearch::Sugar delegates all methods)
response = client.get(
  index: 'my_index',
  id: 'doc123'
)

document = response['_source']
puts document
```

### How to Update a Document

```ruby
# Partial update
client.update(
  index: 'my_index',
  id: 'doc123',
  body: {
    doc: {
      title: 'Updated Title'
    }
  }
)

# Full replacement
client.index(
  index: 'my_index',
  id: 'doc123',
  body: {
    title: 'New Title',
    content: 'New content'
  }
)
```

### How to Bulk Index Documents

```ruby
# Prepare bulk operations
operations = []

documents.each do |doc|
  operations << { index: { _index: 'my_index', _id: doc[:id] } }
  operations << doc
end

# Execute bulk request
response = client.bulk(body: operations)

# Check for errors
if response['errors']
  response['items'].each do |item|
    if item['index']['error']
      puts "Error indexing #{item['index']['_id']}: #{item['index']['error']['reason']}"
    end
  end
else
  puts "Successfully indexed #{operations.size / 2} documents"
end
```

### How to Refresh an Index

```ruby
index = client['my_index']

# Make documents immediately searchable
index.refresh

# Or using the raw client for a different index or all indexes
client.indices.refresh(index: 'other_index')
client.indices.refresh
```

**When to use:**
- After indexing documents in tests
- When you need immediate search results
- Not recommended for production (automatic refresh is fine)

---

## Search and Analysis

### How to Search Documents

```ruby
# Simple match query
response = client.search(
  index: 'my_index',
  body: {
    query: {
      match: {
        title: 'search terms'
      }
    }
  }
)

# Get results
hits = response['hits']['hits']
hits.each do |hit|
  doc = hit['_source']
  score = hit['_score']
  puts "#{doc['title']} (score: #{score})"
end
```

### How to Analyze Text with an Analyzer

```ruby
index = client['my_index']

# Analyze text using a custom analyzer defined on the index
tokens = index.analyze_text(
  analyzer: 'my_custom_analyzer',
  text: 'The quick brown fox jumps'
)

puts tokens.join(', ')
# Output: quick, brown, fox, jumps
```

**Note:** `analyze_text` works with analyzers explicitly defined in the index settings.
Use the raw `client.indices.analyze` API to test built-in analyzers (e.g., `standard`)
without defining them in the index.

### How to Analyze Text Using a Field's Analyzer

```ruby
index = client['my_index']

# Analyze using the analyzer configured for a field
tokens = index.analyze_text_field(
  field: 'title',
  text: 'The quick brown fox'
)
```

**When this fails:**
- Field doesn't exist → Check field name in mappings
- No analyzer specified → Field must have an analyzer configured

### How to List Available Analyzers

```ruby
index = client['my_index']

# Get all analyzers (index + cluster level)
analyzers = index.analyzers
puts "Available analyzers: #{analyzers.join(', ')}"
```

### How to Perform Aggregations

```ruby
# Count by category
response = client.search(
  index: 'products',
  body: {
    size: 0,  # Don't return documents
    aggs: {
      categories: {
        terms: {
          field: 'category.keyword',
          size: 10
        }
      }
    }
  }
)

# Get aggregation results
buckets = response['aggregations']['categories']['buckets']
buckets.each do |bucket|
  puts "#{bucket['key']}: #{bucket['doc_count']}"
end
```

### How to Perform a Multi-field Search

```ruby
response = client.search(
  index: 'my_index',
  body: {
    query: {
      multi_match: {
        query: 'search terms',
        fields: ['title^3', 'description^2', 'content'],
        type: 'best_fields'
      }
    }
  }
)
```

**Field boosting:**
- `^3` = 3x weight
- `^2` = 2x weight
- No boost = 1x weight

---

## Settings and Mappings

### How to Update Index Settings

```ruby
index = client['my_index']

settings = {
  settings: {
    number_of_replicas: 2,
    refresh_interval: '5s',
    analysis: {
      analyzer: {
        my_analyzer: {
          type: 'custom',
          tokenizer: 'standard',
          filter: ['lowercase', 'stop']
        }
      }
    }
  }
}

index.update_settings(settings)
puts "Settings updated!"
```

**The gem automatically:**
- Closes the index before updating
- Applies the settings
- Reopens the index

### How to Get Index Settings

```ruby
index = client['my_index']
settings = index.settings

# Access specific settings
analyzer_config = settings.dig('my_index', 'settings', 'index', 'analysis', 'analyzer')
```

### How to Update Index Mappings

```ruby
index = client['my_index']

mappings = {
  mappings: {
    properties: {
      title: { type: 'text', analyzer: 'standard' },
      category: { type: 'keyword' },
      price: { type: 'float' },
      created_at: { type: 'date' }
    }
  }
}

index.update_mappings(mappings)
```

### How to Get Index Mappings

```ruby
index = client['my_index']
mappings = index.mappings

# Access field mappings
properties = mappings.dig('my_index', 'mappings', 'properties')
```

### How to Create a Custom Analyzer

```ruby
settings = {
  settings: {
    analysis: {
      # Define custom analyzer
      analyzer: {
        email_analyzer: {
          type: 'custom',
          tokenizer: 'uax_url_email',
          filter: ['lowercase']
        }
      },
      # Or use a built-in analyzer with custom config
      custom_standard: {
        type: 'standard',
        max_token_length: 255,
        stopwords: ['the', 'is', 'and']
      }
    }
  }
}

index.update_settings(settings)
```

---

## Aliases

### How to Create an Alias

```ruby
index = client['my_index']
index.create_alias('my_alias')

# Or using raw client
client.indices.put_alias(
  index: 'my_index',
  name: 'my_alias'
)
```

### How to List Index Aliases

```ruby
index = client['my_index']
aliases = index.aliases
puts "Aliases: #{aliases.join(', ')}"
```

### How to Delete an Alias

```ruby
client.indices.delete_alias(
  index: 'my_index',
  name: 'my_alias'
)
```

### How to Switch an Alias to a New Index

```ruby
# Atomic alias switch (for zero-downtime reindexing)
client.indices.update_aliases(
  body: {
    actions: [
      { remove: { index: 'old_index', alias: 'my_alias' } },
      { add: { index: 'new_index', alias: 'my_alias' } }
    ]
  }
)
```

**Use case:** Rolling index updates without downtime

---

## ML Models

### How to Register and Deploy a Model

```ruby
models = client.models

model = models.register(
  name: 'huggingface/sentence-transformers/all-MiniLM-L12-v2',
  version: '1.0.1',
  format: 'TORCH_SCRIPT'
)

puts "Model deployed: #{model.name}"
```

**Note:** Registration includes deployment. The method waits for deployment to complete.

### How to List All Models

```ruby
models = client.models
all_models = models.list

all_models.each do |model|
  puts "#{model.name} v#{model.version} (ID: #{model.id})"
end
```

### How to Find a Model

```ruby
models = client.models

# By exact name
model = models['all-MiniLM-L12-v2']

# By ID
model = models['abc123']

# By partial name (case-insensitive regex)
model = models['minilm']  # Finds latest version
```

### How to Create an Embedding Pipeline

```ruby
models = client.models

models.create_pipeline(
  name: 'text_embedding',
  model: 'all-MiniLM-L12-v2',
  description: 'Generate embeddings for text fields',
  field_map: {
    'text' => 'text_embedding',
    'title' => 'title_embedding'
  }
)
```

### How to Use a Pipeline for Indexing

```ruby
# Index with pipeline
client.index(
  index: 'my_index',
  pipeline: 'text_embedding',
  body: {
    text: 'This is my document text',
    title: 'Document Title'
  }
)

# The pipeline automatically adds embedding fields
```

### How to Undeploy a Model

```ruby
models = client.models
models.undeploy!('all-MiniLM-L12-v2')
```

### How to Delete a Model

```ruby
models = client.models
models.delete!('all-MiniLM-L12-v2')
# This automatically undeploys first
```

---


## Error Handling

### How to Handle Connection Errors

```ruby
require 'opensearch/sugar'

begin
  client = OpenSearch::Sugar.new(
    host: 'https://wrong-host:9200',
    user: 'admin',
    password: 'wrong'
  )
  puts "Connected successfully"
rescue OpenSearch::Transport::Transport::Error => e
  puts "Connection failed: #{e.message}"
end
```

### How to Handle Index Not Found

```ruby
begin
  index = OpenSearch::Sugar::Index.open(
    client: client,
    name: 'nonexistent_index'
  )
rescue ArgumentError => e
  puts "Error: #{e.message}"
  # Create the index instead
  index = OpenSearch::Sugar::Index.create(
    client: client,
    name: 'nonexistent_index'
  )
end
```

### How to Handle Bulk Operation Errors

```ruby
response = client.bulk(body: operations)

if response['errors']
  errors = []
  response['items'].each do |item|
    if error = item.dig('index', 'error')
      errors << {
        id: item['index']['_id'],
        reason: error['reason'],
        type: error['type']
      }
    end
  end
  
  puts "Bulk operation had #{errors.size} errors:"
  errors.each do |err|
    puts "  - #{err[:id]}: #{err[:reason]}"
  end
else
  puts "Bulk operation successful"
end
```

### How to Handle Analyzer Not Found

```ruby
index = client['my_index']

begin
  tokens = index.analyze_text(
    analyzer: 'nonexistent_analyzer',
    text: 'some text'
  )
rescue ArgumentError => e
  puts "Error: #{e.message}"
  # List available analyzers
  puts "Available: #{index.analyzers.join(', ')}"
end
```

### How to Retry Failed Operations

```ruby
max_retries = 3
retry_count = 0

begin
  client.index(
    index: 'my_index',
    id: 'doc123',
    body: { title: 'My Document' }
  )
rescue OpenSearch::Transport::Transport::Error => e
  retry_count += 1
  if retry_count < max_retries
    puts "Retry #{retry_count}/#{max_retries}"
    sleep(2 ** retry_count)  # Exponential backoff
    retry
  else
    puts "Failed after #{max_retries} retries: #{e.message}"
    raise
  end
end
```

---

## Additional Resources

- [OpenSearch Documentation](https://opensearch.org/docs/latest/)
- [OpenSearch API Reference](https://opensearch.org/docs/latest/api-reference/)
- [Tutorial](TUTORIAL.md) - Learning-oriented guide
- [Reference](REFERENCE.md) - Complete API documentation
- [Explanation](EXPLANATION.md) - Understanding concepts

