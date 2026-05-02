# Index Alias API Design Notes

Working notes for expanding alias support in `OpenSearch::Sugar::Index`.
Not finished — pick up here.

---

## Current state

`Index` has two alias methods:

```ruby
def aliases
  # Returns Array<String> of alias names only
  response = client.indices.get_alias(index: name)
  response.dig(name, "aliases")&.keys || []
end

def create_alias(alias_name)
  # Creates the alias, returns updated Array<String>
  client.indices.put_alias(index: name, name: alias_name)
  aliases
end
```

Covered by `spec/opensearch/sugar/index/aliases_spec.rb`.

---

## Critique of current methods

**`#aliases`**
- Name is fine; reads naturally.
- Lossy: discards all alias metadata (`filter`, `routing`, `is_write_index`). Can't answer "is this a write alias?" without hitting the raw client.

**`#create_alias`**
- Name is clear.
- The `@raise BadRequest` YARD note is misleading — OpenSearch may silently move the alias rather than error, depending on configuration.
- No support for alias-level parameters: `filter`, `routing`, `index_routing`, `search_routing`, `is_write_index`.

---

## What the OpenSearch API offers (not yet wrapped)

### Missing operations

| Method | HTTP | Notes |
|---|---|---|
| `delete_alias(name)` | `DELETE /<index>/_alias/<alias>` | Symmetry with create |
| `alias?(name)` | `HEAD /<index>/_alias/<alias>` | Returns bool; 200 = exists |
| Atomic swap | `POST /_aliases` (bulk actions) | add + remove in one atomic call; standard for zero-downtime reindex |

### Missing parameters on `create_alias`

| Param | Type | Purpose |
|---|---|---|
| `filter:` | Hash (query DSL) | Filtered alias — only surfaces matching docs |
| `is_write_index:` | Boolean | Designates this index as the write target |
| `routing:` | String | Routing for both index and search |
| `index_routing:` | String | Routing for indexing only |
| `search_routing:` | String | Routing for search only |

---

## Design options

### Option A — Simple completeness (no breaking changes)

Keep `aliases` returning `Array<String>`. Add missing operations and params.

```
#aliases                                    → Array<String>   (unchanged)
#create_alias(name, filter: nil,            → Array<String>   (add keyword params)
              routing: nil, is_write_index: nil)
#delete_alias(name)                         → Array<String>   (new)
#alias?(name)                               → Boolean         (new)
```

Atomic swap is not covered; caller uses raw client.

### Option B — Richer return values + atomic swap

```
#aliases                                    → Hash<String, Hash>  (BREAKING — name => metadata)
#add_alias(name, **opts)                    → Hash             (rename of create_alias)
#remove_alias(name)                         → Hash
#alias?(name)                               → Boolean
#swap_alias(from:, to:)                     → result of /_aliases bulk call
```

Rename `aliases` return type is breaking unless old method is aliased.

### Option C — Separate name list from full detail

```
#alias_names                                → Array<String>   (rename of current #aliases)
#aliases                                    → Hash<String, Hash>  (full metadata)
#create_alias(name, **opts)                 → keep name, add opts
#delete_alias(name)                         → new
#alias?(name)                               → new
#swap_alias(old_alias:, new_alias:)         → new
```

---

## Open questions

1. Should `aliases` stay `Array<String>` or become a richer Hash (with metadata)?
2. `delete_alias` vs `remove_alias` — match the API verb (`delete`) or use a softer Ruby name (`remove`)?
3. Is `swap_alias` worth adding? It's the standard pattern for zero-downtime index cutover.
4. Should `create_alias` grow keyword params (`filter:`, `routing:`, `is_write_index:`) or stay simple?

---

## Recommendation (starting point)

Option A is the lowest-risk starting point — no breaking changes, fills the obvious gaps.
Add `delete_alias`, `alias?`, and keyword params on `create_alias`.
If `swap_alias` is wanted, add it standalone — it's high value for reindex workflows.
