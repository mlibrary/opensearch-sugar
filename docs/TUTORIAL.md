# Getting Started with opensearch-sugar

By the end of this tutorial you will have a running, searchable book catalog: a live
OpenSearch index with custom text analysis, structured field mappings, real documents,
and a working full-text search query.

## What you'll build

A Ruby script that connects to a local OpenSearch cluster, configures a `books` index
with a custom analyzer, adds three documents, and queries them by keyword.

## Before you start

- Ruby 3.1 or higher
- Docker installed and running
- Basic familiarity with running Ruby scripts from the terminal

---

## Step 1: Start OpenSearch

Run a single-node OpenSearch container:

```bash
docker run -d \
  -p 9200:9200 \
  -e "discovery.type=single-node" \
  -e "OPENSEARCH_INITIAL_ADMIN_PASSWORD=MyPassword123!" \
  --name opensearch-tutorial \
  opensearchproject/opensearch:latest
```

Wait about 30 seconds, then confirm it is up:

```bash
curl -sk https://localhost:9200 -u admin:MyPassword123! | ruby -e "require 'json'; puts JSON.parse(STDIN.read)['tagline']"
```

The output should be:

```
The OpenSearch Project: https://opensearch.org/
```

## Step 2: Install the gem

Create a project directory and a `Gemfile`:

```bash
mkdir book-catalog && cd book-catalog
```

```ruby
# Gemfile
source "https://rubygems.org"
gem "opensearch-sugar"
gem "dotenv"
```

```bash
bundle install
```

Create a `.env` file with your connection details:

```
OPENSEARCH_URL=https://localhost:9200
OPENSEARCH_USER=admin
OPENSEARCH_PASSWORD=MyPassword123!
```

## Step 3: Connect to the cluster

Create `catalog.rb`:

```ruby
require "opensearch/sugar"
require "dotenv/load"

client = OpenSearch::Sugar::Client.new
puts client.ping ? "Connected!" : "Could not connect"
puts "Existing indexes: #{client.index_names}"
```

Run it:

```bash
bundle exec ruby catalog.rb
```

You should see:

```
Connected!
Existing indexes: []
```

Notice that `index_names` returns only user-created indexes — system indexes are hidden.

## Step 4: Create the books index

Add to `catalog.rb`:

```ruby
index = client.open_or_create_index("books")
puts "Index '#{index.name}' ready. Documents: #{index.count}"
```

The output should be:

```
Index 'books' ready. Documents: 0
```

Notice that `open_or_create_index` is safe to call repeatedly — it creates the index on
the first run and opens it on subsequent runs.

## Step 5: Configure a custom analyzer

Add the settings block. This must be done before you add documents:

```ruby
index.update_settings(
  settings: {
    analysis: {
      filter: {
        book_stop: {
          type: "stop",
          stopwords: ["the", "a", "an", "and", "or", "of"]
        }
      },
      analyzer: {
        book_title: {
          type: "custom",
          tokenizer: "standard",
          filter: ["lowercase", "asciifolding", "book_stop"]
        }
      }
    }
  }
)
puts "Settings applied."
```

## Step 6: Map the fields

```ruby
index.update_mappings(
  mappings: {
    properties: {
      title:       { type: "text", analyzer: "book_title" },
      author:      { type: "text" },
      description: { type: "text", analyzer: "book_title" },
      isbn:        { type: "keyword" },
      year:        { type: "integer" },
      categories:  { type: "keyword" }
    }
  }
)
puts "Mappings applied."
```

## Step 7: Verify the analyzer

Before adding data, confirm the analyzer tokenizes as expected:

```ruby
tokens = index.test_analyzer_by_name(analyzer: "book_title", text: "The Lord of the Rings")
puts "Tokens: #{tokens.join(", ")}"
```

The output should be:

```
Tokens: lord, rings
```

Notice that "the", "of", and "a" are removed by the `book_stop` filter — those words
will not be indexed and do not need to appear in queries.

## Step 8: Add books

```ruby
books = [
  {
    title: "The Hobbit",
    author: "J.R.R. Tolkien",
    description: "A hobbit's unexpected journey through Middle-earth.",
    isbn: "978-0547928227",
    year: 1937,
    categories: ["fantasy", "adventure"]
  },
  {
    title: "1984",
    author: "George Orwell",
    description: "A dystopian novel about totalitarian surveillance.",
    isbn: "978-0451524935",
    year: 1949,
    categories: ["dystopian", "classic"]
  },
  {
    title: "To Kill a Mockingbird",
    author: "Harper Lee",
    description: "Racial injustice in the American South, seen through a child's eyes.",
    isbn: "978-0061120084",
    year: 1960,
    categories: ["classic", "drama"]
  }
]

books.each { |b| index.index_document(b, b[:isbn]) }
index.refresh
puts "Indexed #{index.count} books."
```

The output should be:

```
Indexed 3 books.
```

Notice the call to `index.refresh` — without it, the documents may not be visible to
search queries immediately.

## Step 9: Compare index-time and search-time tokenization

Before searching, confirm how your analyzer transforms text — this makes unexpected
search results much easier to diagnose later.

```ruby
title = "The Fellowship of the Ring"

index_tokens  = index.test_analyzer_by_name(analyzer: "book_title", text: title)
search_tokens = index.test_analyzer_by_name(analyzer: "standard",   text: title)

puts "Indexed as:  #{index_tokens.join(", ")}"
puts "Standard as: #{search_tokens.join(", ")}"
```

The output should be:

```
Indexed as:  fellowship, ring
Standard as: the, fellowship, the, ring
```

Notice that `book_title` removes stop words ("the", "of") while the built-in `standard`
analyzer keeps them. A query using `standard` would include tokens your index never
stored — understanding this gap is the key to debugging zero-result searches.

## Step 10: Search the catalog



```ruby
results = client.search(
  index: "books",
  body: {
    query: {
      multi_match: {
        query: "fantasy adventure",
        fields: ["title^2", "description", "categories"]
      }
    }
  }
)

puts "\nSearch results for 'fantasy adventure':"
results["hits"]["hits"].each do |hit|
  src = hit["_source"]
  puts "  #{src["title"]} by #{src["author"]} (score: #{hit["_score"].round(2)})"
end
```

The output should be:

```
Search results for 'fantasy adventure':
  The Hobbit by J.R.R. Tolkien (score: 1.23)
```

Notice that `client.search` is the standard OpenSearch Ruby client method — opensearch-sugar
delegates all methods it does not define directly to the underlying client.

## Step 11: Create an alias

```ruby
index.create_alias("current_catalog")
puts "Aliases: #{index.aliases.join(", ")}"

# Access the same index through the alias
via_alias = client["current_catalog"]
puts "Documents via alias: #{via_alias.count}"
```

The output should be:

```
Aliases: current_catalog
Documents via alias: 3
```

## What you've built

You have connected to OpenSearch, created a custom analyzer, mapped fields, indexed
documents, run a full-text search, and set up an alias.

Your `catalog.rb` is now a working foundation for any Ruby application that needs
structured, full-text search.

## Next steps

- **Solve specific problems** → [How-to Guides](HOWTO.md)
- **Look up a method** → [API Reference](REFERENCE.md)
- **Understand the design** → [Explanation](EXPLANATION.md)

## Clean up

```ruby
index.delete!
```

```bash
docker stop opensearch-tutorial && docker rm opensearch-tutorial
```
