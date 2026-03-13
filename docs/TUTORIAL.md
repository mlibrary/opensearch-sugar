# Getting Started with OpenSearch::Sugar

*(Documentation written by GitHub Copilot, powered by Claude Sonnet 4.5)*

This tutorial will guide you through building your first OpenSearch application using OpenSearch::Sugar. By the end, you'll have created a searchable book catalog with custom analyzers and full-text search capabilities.

## What You'll Learn

- How to connect to OpenSearch
- How to create and configure an index
- How to define custom analyzers
- How to add and query documents
- How to use text analysis features

## Prerequisites

- Ruby 3.1 or higher installed
- Docker (for running OpenSearch locally)
- Basic Ruby knowledge
- Familiarity with command line

## Step 1: Set Up Your Environment

### Install OpenSearch

First, let's start an OpenSearch instance using Docker:

```bash
docker run -d \
  -p 9200:9200 \
  -p 9600:9600 \
  -e "discovery.type=single-node" \
  -e "OPENSEARCH_INITIAL_ADMIN_PASSWORD=MyPassword123!" \
  --name opensearch-tutorial \
  opensearchproject/opensearch:latest
```

Wait a few seconds for OpenSearch to start, then verify it's running:

```bash
curl -X GET "https://localhost:9200" -ku admin:MyPassword123!
```

You should see a JSON response with cluster information.

### Install the Gem

Create a new Ruby project:

```bash
mkdir book-catalog
cd book-catalog
```

Create a `Gemfile`:

```ruby
source 'https://rubygems.org'

gem 'opensearch-sugar'
gem 'dotenv'  # For managing environment variables
```

Install dependencies:

```bash
bundle install
```

### Configure Connection

Create a `.env` file with your OpenSearch connection details:

```bash
OPENSEARCH_URL=https://localhost:9200
OPENSEARCH_USER=admin
OPENSEARCH_PASSWORD=MyPassword123!
```

## Step 2: Connect to OpenSearch

Create a file called `catalog.rb` and add:

```ruby
require 'opensearch/sugar'
require 'dotenv/load'

# Create a client - it will automatically use environment variables
client = OpenSearch::Sugar.new

puts "Connected to OpenSearch!"
puts "Available indexes: #{client.index_names.join(', ')}"
```

Run it:

```bash
ruby catalog.rb
```

You should see a confirmation that you're connected!

## Step 3: Create Your First Index

Let's create an index for storing books. Add to your `catalog.rb`:

```ruby
# Create or open the books index
index = client.open_or_create('books')

puts "Index 'books' is ready!"
puts "Document count: #{index.count}"
```

Run it again. The index is now created!

## Step 4: Configure Custom Analyzers

Books need good text analysis for searching. Let's add a custom analyzer that handles book titles and descriptions well.

Add this to your script:

```ruby
# Define custom analyzers for book text
settings = {
  settings: {
    analysis: {
      # Custom analyzers
      analyzer: {
        book_title_analyzer: {
          type: 'custom',
          tokenizer: 'standard',
          filter: ['lowercase', 'asciifolding', 'book_stop_filter']
        },
        book_search_analyzer: {
          type: 'custom',
          tokenizer: 'standard',
          filter: ['lowercase', 'asciifolding']
        }
      },
      # Custom stop words filter
      filter: {
        book_stop_filter: {
          type: 'stop',
          stopwords: ['the', 'a', 'an', 'and', 'or', 'but']
        }
      }
    }
  }
}

index.update_settings(settings)
puts "Settings updated successfully"
```

**What's happening here?**
- `book_title_analyzer` removes common words like "the" and "a"
- `book_search_analyzer` keeps all words for broader searching
- Both handle special characters with `asciifolding`

## Step 5: Define Field Mappings

Now let's define the structure of our book documents:

```ruby
mappings = {
  mappings: {
    properties: {
      title: {
        type: 'text',
        analyzer: 'book_title_analyzer',
        search_analyzer: 'book_search_analyzer',
        fields: {
          keyword: { type: 'keyword' }  # For exact matching
        }
      },
      author: {
        type: 'text',
        fields: {
          keyword: { type: 'keyword' }
        }
      },
      description: {
        type: 'text',
        analyzer: 'book_title_analyzer'
      },
      isbn: {
        type: 'keyword'
      },
      published_date: {
        type: 'date'
      },
      pages: {
        type: 'integer'
      },
      categories: {
        type: 'keyword'
      },
      rating: {
        type: 'float'
      }
    }
  }
}

index.update_mappings(mappings)
puts "Mappings updated successfully"
```

## Step 6: Test Your Analyzer

Before adding documents, let's verify our analyzer works correctly:

```ruby
# Test the analyzer
sample_title = "The Lord of the Rings: The Fellowship of the Ring"
tokens = index.analyze_text(
  analyzer: 'book_title_analyzer',
  text: sample_title
)

puts "\nOriginal: #{sample_title}"
puts "Tokens: #{tokens.join(', ')}"
# Output: lord, rings, fellowship, ring
# Notice "the" and "of" are removed!
```

This shows how OpenSearch will index book titles - common words are removed to improve search relevance.

## Step 7: Add Some Books

Now let's add books using the raw client (OpenSearch::Sugar delegates all standard client methods):

```ruby
# Add some books
books = [
  {
    title: "The Hobbit",
    author: "J.R.R. Tolkien",
    description: "A fantasy adventure about a hobbit's unexpected journey.",
    isbn: "978-0547928227",
    published_date: "1937-09-21",
    pages: 310,
    categories: ["fantasy", "adventure", "classic"],
    rating: 4.7
  },
  {
    title: "1984",
    author: "George Orwell",
    description: "A dystopian novel about totalitarianism and surveillance.",
    isbn: "978-0451524935",
    published_date: "1949-06-08",
    pages: 328,
    categories: ["dystopian", "political", "classic"],
    rating: 4.6
  },
  {
    title: "To Kill a Mockingbird",
    author: "Harper Lee",
    description: "A novel about racial injustice in the American South.",
    isbn: "978-0061120084",
    published_date: "1960-07-11",
    pages: 324,
    categories: ["classic", "legal", "drama"],
    rating: 4.8
  }
]

books.each do |book|
  # Use the raw client for indexing
  client.index(
    index: 'books',
    id: book[:isbn],
    body: book
  )
end

# Refresh to make documents searchable immediately
client.indices.refresh(index: 'books')

puts "\nAdded #{books.size} books!"
puts "Total documents: #{index.count}"
```

## Step 8: Search Your Catalog

Now let's search! Add this to test searching:

```ruby
# Search for books
search_response = client.search(
  index: 'books',
  body: {
    query: {
      multi_match: {
        query: 'fantasy adventure',
        fields: ['title^2', 'description', 'categories']
      }
    }
  }
)

puts "\nSearch results for 'fantasy adventure':"
search_response['hits']['hits'].each do |hit|
  book = hit['_source']
  puts "  - #{book['title']} by #{book['author']} (score: #{hit['_score']})"
end
```

## Step 9: Analyze Search Behavior

Let's see how our analyzer affects search results:

```ruby
# Compare analyzers
title = "The Complete Adventures of Sherlock Holmes"

puts "\nAnalyzing: #{title}"

# With stop words removed
tokens_indexed = index.analyze_text(
  analyzer: 'book_title_analyzer',
  text: title
)
puts "Indexed tokens (with stop filter): #{tokens_indexed.join(', ')}"

# Without stop words removed
tokens_search = index.analyze_text(
  analyzer: 'book_search_analyzer',
  text: title
)
puts "Search tokens (without stop filter): #{tokens_search.join(', ')}"
```

## Step 10: Create an Alias

Create an alias for easy access:

```ruby
# Create an alias
index.create_alias('current_catalog')

puts "\nAliases for 'books': #{index.aliases.join(', ')}"

# Now you can use the alias
alias_index = client['current_catalog']
puts "Documents via alias: #{alias_index.count}"
```

## What You've Accomplished

Congratulations! You've built a complete searchable book catalog:

- ✅ Connected to OpenSearch
- ✅ Created a custom index with analyzers
- ✅ Defined field mappings for structured data
- ✅ Added documents with proper indexing
- ✅ Performed full-text searches
- ✅ Analyzed how text processing works
- ✅ Created index aliases

## Complete Script

Here's the complete `catalog.rb` for reference:

```ruby
require 'opensearch/sugar'
require 'dotenv/load'

# Connect
client = OpenSearch::Sugar.new
index = client.open_or_create('books')

# Configure settings
settings = {
  settings: {
    analysis: {
      analyzer: {
        book_title_analyzer: {
          type: 'custom',
          tokenizer: 'standard',
          filter: ['lowercase', 'asciifolding', 'book_stop_filter']
        },
        book_search_analyzer: {
          type: 'custom',
          tokenizer: 'standard',
          filter: ['lowercase', 'asciifolding']
        }
      },
      filter: {
        book_stop_filter: {
          type: 'stop',
          stopwords: ['the', 'a', 'an', 'and', 'or', 'but']
        }
      }
    }
  }
}
index.update_settings(settings)

# Configure mappings
mappings = {
  mappings: {
    properties: {
      title: {
        type: 'text',
        analyzer: 'book_title_analyzer',
        search_analyzer: 'book_search_analyzer',
        fields: { keyword: { type: 'keyword' } }
      },
      author: { type: 'text', fields: { keyword: { type: 'keyword' } } },
      description: { type: 'text', analyzer: 'book_title_analyzer' },
      isbn: { type: 'keyword' },
      published_date: { type: 'date' },
      pages: { type: 'integer' },
      categories: { type: 'keyword' },
      rating: { type: 'float' }
    }
  }
}
index.update_mappings(mappings)

# Add books
books = [
  {
    title: "The Hobbit",
    author: "J.R.R. Tolkien",
    description: "A fantasy adventure about a hobbit's unexpected journey.",
    isbn: "978-0547928227",
    published_date: "1937-09-21",
    pages: 310,
    categories: ["fantasy", "adventure", "classic"],
    rating: 4.7
  }
  # ... add more books
]

books.each do |book|
  client.index(index: 'books', id: book[:isbn], body: book)
end

client.indices.refresh(index: 'books')
puts "Created catalog with #{index.count} books!"
```

## Next Steps

Now that you understand the basics, explore:

- **[How-to Guides](HOWTO.md)** - Solve specific problems
- **[Reference Documentation](REFERENCE.md)** - Complete API details
- **[Explanation](EXPLANATION.md)** - Understand design decisions
- **[OpenSearch Documentation](https://opensearch.org/docs/latest/)** - Deep dive into OpenSearch features

## Cleanup

When you're done experimenting:

```ruby
# Delete the index
index.delete!

# Stop the Docker container
# docker stop opensearch-tutorial
# docker rm opensearch-tutorial
```

## Troubleshooting

**Connection refused?**
- Make sure OpenSearch is running: `docker ps`
- Check the URL in your `.env` file

**SSL certificate errors with self-signed certificates?**
- SSL verification is **enabled by default** for security
- For local development with self-signed certificates, you can disable it:
  ```ruby
  client = OpenSearch::Sugar.new(
    transport_options: { ssl: { verify: false } }
  )
  ```
- For production, use proper SSL certificates

**Index already exists?**
- Delete it first: `client.indices.delete(index: 'books')`
- Or use `open_or_create` instead of `create`

**Settings update fails?**
- Some settings can't be changed on an open index
- The gem automatically closes/reopens the index for you
- If it fails, check the error message

## Resources

- [OpenSearch Index Settings](https://opensearch.org/docs/latest/install-and-configure/configuring-opensearch/index-settings/)
- [OpenSearch Analyzers](https://opensearch.org/docs/latest/analyzers/)
- [OpenSearch Mapping](https://opensearch.org/docs/latest/field-types/)
- [OpenSearch Query DSL](https://opensearch.org/docs/latest/query-dsl/)

