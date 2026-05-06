# Delegated Method Calls in HOWTO.md

*(Documentation written by GitHub Copilot, powered by Claude Sonnet 4.5)*

This document identifies all method calls in HOWTO.md that rely on delegation to the underlying `OpenSearch::Client` rather than using OpenSearch::Sugar's own implemented methods.

## OpenSearch::Sugar Implemented Methods

### Client Methods (OpenSearch::Sugar::Client)
- `set_log_level(logger:, level:)`
- `has_index?(name)`
- `index_names`
- `[](index_name)` - index accessor
- `open_or_create(index_name)`
- `update_settings(settings, index_name)`
- `update_mappings(mappings, index_name)`
- `models` - accessor for Models instance
- `raw_client` - accessor for underlying client

### Index Methods (OpenSearch::Sugar::Index)
- `update_settings(settings)`
- `settings`
- `update_mappings(mappings)`
- `mappings`
- `delete!`
- `count`
- `aliases`
- `create_alias(alias_name)`
- `all_available_analyzers` / `analyzers`
- `analyze_text(analyzer:, text:)`
- `analyze_text_field(field:, text:)`
- `delete_by_id(id)`
- `clear!`

---

## Delegated Method Calls in HOWTO.md

### Connection and Configuration Section

**Line 94: `client.cluster.health`**
```ruby
response = client.cluster.health
```
- **Delegated to:** `OpenSearch::Client#cluster`
- **OpenSearch API:** [Cluster Health API](https://opensearch.org/docs/latest/api-reference/cluster-api/cluster-health/)
- **Purpose:** Get cluster health status

---

### Index Management Section

**Line 175: `client.indices.delete(index: 'my_index')`**
```ruby
client.indices.delete(index: 'my_index')
```
- **Delegated to:** `OpenSearch::Client#indices.delete`
- **OpenSearch API:** [Delete Index API](https://opensearch.org/docs/latest/api-reference/index-apis/delete-index/)
- **Note:** Sugar alternative exists: `index.delete!`

---

### Document Operations Section

**Line 196-203: `client.index(...)`**
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
```
- **Delegated to:** `OpenSearch::Client#index`
- **OpenSearch API:** [Index Document API](https://opensearch.org/docs/latest/api-reference/document-apis/index-document/)
- **Purpose:** Index a single document

**Line 220: `client.delete(index: 'my_index', id: 'doc123')`**
```ruby
client.delete(index: 'my_index', id: 'doc123')
```
- **Delegated to:** `OpenSearch::Client#delete`
- **OpenSearch API:** [Delete Document API](https://opensearch.org/docs/latest/api-reference/document-apis/delete-document/)
- **Note:** Sugar alternative exists: `index.delete_by_id('doc123')`

**Line 237-242: `client.get(...)`**
```ruby
response = client.get(
  index: 'my_index',
  id: 'doc123'
)

document = response['_source']
```
- **Delegated to:** `OpenSearch::Client#get`
- **OpenSearch API:** [Get Document API](https://opensearch.org/docs/latest/api-reference/document-apis/get-documents/)
- **Purpose:** Retrieve a document by ID

**Line 250-271: `client.update(...)`**
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
- **Delegated to:** `OpenSearch::Client#update`
- **OpenSearch API:** [Update Document API](https://opensearch.org/docs/latest/api-reference/document-apis/update-document/)
- **Purpose:** Update an existing document

**Line 283: `client.bulk(body: operations)`**
```ruby
response = client.bulk(body: operations)
```
- **Delegated to:** `OpenSearch::Client#bulk`
- **OpenSearch API:** [Bulk API](https://opensearch.org/docs/latest/api-reference/document-apis/bulk/)
- **Purpose:** Perform multiple index/delete operations in a single request

**Line 301-304: `client.indices.refresh(...)`**
```ruby
# Make documents immediately searchable
client.indices.refresh(index: 'my_index')

# Refresh all indexes
client.indices.refresh
```
- **Delegated to:** `OpenSearch::Client#indices.refresh`
- **OpenSearch API:** [Refresh API](https://opensearch.org/docs/latest/api-reference/index-apis/refresh/)
- **Purpose:** Make recent changes searchable

---

### Search and Analysis Section

**Line 320-334: `client.search(...)`**
```ruby
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

hits = response['hits']['hits']
```
- **Delegated to:** `OpenSearch::Client#search`
- **OpenSearch API:** [Search API](https://opensearch.org/docs/latest/api-reference/search/)
- **Purpose:** Execute a search query

**Line 391-406: `client.search(...)` with aggregations**
```ruby
response = client.search(
  index: 'products',
  body: {
    size: 0,
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
```
- **Delegated to:** `OpenSearch::Client#search`
- **OpenSearch API:** [Search API with Aggregations](https://opensearch.org/docs/latest/aggregations/)
- **Purpose:** Perform aggregations

**Line 416-426: `client.search(...)` with multi_match**
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
- **Delegated to:** `OpenSearch::Client#search`
- **OpenSearch API:** [Multi-Match Query](https://opensearch.org/docs/latest/query-dsl/full-text/multi-match/)
- **Purpose:** Search across multiple fields

---

### Aliases Section

**Line 547-550: `client.indices.put_alias(...)`**
```ruby
client.indices.put_alias(
  index: 'my_index',
  name: 'my_alias'
)
```
- **Delegated to:** `OpenSearch::Client#indices.put_alias`
- **OpenSearch API:** [Create Alias API](https://opensearch.org/docs/latest/api-reference/alias/)
- **Note:** Sugar alternative exists: `index.create_alias('my_alias')`

**Line 564-567: `client.indices.delete_alias(...)`**
```ruby
client.indices.delete_alias(
  index: 'my_index',
  name: 'my_alias'
)
```
- **Delegated to:** `OpenSearch::Client#indices.delete_alias`
- **OpenSearch API:** [Delete Alias API](https://opensearch.org/docs/latest/api-reference/alias/)
- **Purpose:** Remove an alias

**Line 574-582: `client.indices.update_aliases(...)`**
```ruby
client.indices.update_aliases(
  body: {
    actions: [
      { remove: { index: 'old_index', alias: 'my_alias' } },
      { add: { index: 'new_index', alias: 'my_alias' } }
    ]
  }
)
```
- **Delegated to:** `OpenSearch::Client#indices.update_aliases`
- **OpenSearch API:** [Update Aliases API](https://opensearch.org/docs/latest/api-reference/alias/)
- **Purpose:** Atomic alias operations (swap aliases)

---

### ML Models Section

**Line 652-660: `client.index(...)` with pipeline**
```ruby
client.index(
  index: 'my_index',
  pipeline: 'text_embedding',
  body: {
    text: 'This is my document text',
    title: 'Document Title'
  }
)
```
- **Delegated to:** `OpenSearch::Client#index`
- **OpenSearch API:** [Index with Pipeline](https://opensearch.org/docs/latest/ingest-pipelines/)
- **Purpose:** Index document using an ingest pipeline

---

### Error Handling Section

**Line 722: `client.bulk(body: operations)`**
```ruby
response = client.bulk(body: operations)
```
- **Delegated to:** `OpenSearch::Client#bulk`
- **OpenSearch API:** [Bulk API](https://opensearch.org/docs/latest/api-reference/document-apis/bulk/)
- **Purpose:** Bulk operations error handling example

**Line 769-774: `client.index(...)` in retry example**
```ruby
client.index(
  index: 'my_index',
  id: 'doc123',
  body: { title: 'My Document' }
)
```
- **Delegated to:** `OpenSearch::Client#index`
- **OpenSearch API:** [Index Document API](https://opensearch.org/docs/latest/api-reference/document-apis/index-document/)
- **Purpose:** Retry pattern example

---

## Summary Statistics

### Total Delegated Method Calls: 19 unique examples

### Breakdown by Category:
- **Connection & Configuration:** 1
- **Index Management:** 1
- **Document Operations:** 7
- **Search & Analysis:** 3
- **Aliases:** 3
- **ML Models:** 1
- **Error Handling:** 2 (duplicates of above)

### Most Common Delegated Methods:
1. `client.index(...)` - 5 occurrences (indexing documents)
2. `client.search(...)` - 3 occurrences (searching)
3. `client.bulk(...)` - 2 occurrences (bulk operations)
4. `client.indices.*` - 6 occurrences (various index operations)
5. `client.cluster.*` - 1 occurrence (cluster health)
6. `client.get(...)` - 1 occurrence (get document)
7. `client.update(...)` - 1 occurrence (update document)
8. `client.delete(...)` - 1 occurrence (delete document)

### Methods with Sugar Alternatives Available:
- `client.indices.delete(index: 'my_index')` → `index.delete!`
- `client.delete(index: 'my_index', id: 'doc123')` → `index.delete_by_id('doc123')`
- `client.indices.put_alias(...)` → `index.create_alias('my_alias')`

### Methods Without Sugar Alternatives (Must Use Delegation):
- `client.index(...)` - Document indexing
- `client.get(...)` - Get document by ID
- `client.update(...)` - Update document
- `client.search(...)` - Search queries
- `client.bulk(...)` - Bulk operations
- `client.indices.refresh(...)` - Refresh index
- `client.indices.delete_alias(...)` - Delete alias
- `client.indices.update_aliases(...)` - Atomic alias updates
- `client.cluster.health` - Cluster health

---

## Recommendation

The documentation correctly demonstrates the delegation pattern by showing:
1. **When Sugar methods exist** - it generally uses them (like `index.count`, `index.delete!`, `index.create_alias`)
2. **When Sugar methods don't exist** - it demonstrates delegation (like `client.search`, `client.index`, `client.bulk`)
3. **Both options when available** - showing users they have choices

This aligns with OpenSearch::Sugar's design philosophy: "Use sugar where you want it, raw client where you need it."

The documentation could be improved by adding a note in each delegated example indicating:
```ruby
# Using delegation - OpenSearch::Sugar::Client forwards this to OpenSearch::Client
client.search(...)
```

This would make it clearer to users which methods are delegated vs. implemented.

