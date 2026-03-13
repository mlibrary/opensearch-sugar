# Integration Tests Quick Reference

## Quick Start

```bash
# 1. Start OpenSearch
docker-compose up -d

# 2. Run tests
./run-integration-tests.sh

# Or manually:
RUN_INTEGRATION_TESTS=true bundle exec rake integration
```

## Common Commands

```bash
# Run all integration tests
RUN_INTEGRATION_TESTS=true bundle exec rake integration

# Run specific test file
RUN_INTEGRATION_TESTS=true bundle exec rspec spec/integration/client_spec.rb

# Run specific test by line number
RUN_INTEGRATION_TESTS=true bundle exec rspec spec/integration/index_spec.rb:42

# Run with verbose output
RUN_INTEGRATION_TESTS=true bundle exec rspec spec/integration --format documentation

# Run only unit tests (exclude integration)
bundle exec rake unit
```

## Docker Commands

```bash
# Start OpenSearch
docker-compose up -d opensearch

# Check status
docker-compose ps

# View logs
docker-compose logs -f opensearch

# Stop OpenSearch
docker-compose down

# Clean up volumes
docker-compose down -v
```

## Environment Variables

```bash
export OPENSEARCH_URL=http://localhost:9200
export OPENSEARCH_USER=admin
export OPENSEARCH_PASSWORD=admin
export RUN_INTEGRATION_TESTS=true
```

## Cleanup

```bash
# Delete all test indices
curl -X DELETE "http://localhost:9200/test_opensearch_sugar_*"

# Or in Ruby console
bin/console
> client = OpenSearch::Sugar::Client.new(url: "http://localhost:9200")
> indices = client.cat.indices(format: "json")
> indices.select { |i| i["index"].start_with?("test_") }.each { |i| client.index(i["index"]).delete }
```

## Test Structure

```
spec/integration/
├── client_spec.rb       # Client operations (89 examples)
├── index_spec.rb        # Index operations (126 examples)
└── README.md

spec/support/
├── integration_helper.rb   # Test helpers
└── retry_config.rb         # Retry configuration
```

## Helper Methods

```ruby
# Client
test_client                          # Get configured client

# Index management
test_index_name                      # Generate unique index name
test_index_name("books")             # Generate named index
create_test_index                    # Create test index
create_test_index(mappings: {...})   # With mappings

# Data generation
generate_document                    # Single document
generate_documents(10)               # Multiple documents
generate_documents(5) { |doc, i| ... }  # With customization

# Synchronization
wait_for_index(name)                 # Wait for index ready
wait_for_documents(index)            # Wait for refresh
wait_for_documents(index, expected_count: 10)  # Wait for count

# Mappings & Settings
book_mapping                         # Sample book mapping
standard_settings                    # Default settings
standard_settings(shards: 2, replicas: 1)  # Custom

# Cleanup
cleanup_test_indices                 # Clean all test indices
```

## Retry Tags

```ruby
it "test name", :retry_on_search do
  # 5 retries, 0.5s wait
end

it "test name", :retry_on_cluster do
  # 3 retries, 2s wait
end

# No tag = default: 3 retries, 1s wait
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Tests skipped | Set `RUN_INTEGRATION_TESTS=true` |
| Connection refused | Start OpenSearch: `docker-compose up -d` |
| Timeouts | Check OpenSearch logs: `docker-compose logs opensearch` |
| Flaky tests | Tests auto-retry; consistent fails are real bugs |
| Cleanup needed | `curl -X DELETE "http://localhost:9200/test_opensearch_sugar_*"` |

## Example Test

```ruby
require "spec_helper"

RSpec.describe "My Feature", type: :integration do
  let(:index) { create_test_index(mappings: book_mapping) }
  
  it "performs search", :retry_on_search do
    # Create documents
    docs = generate_documents(10)
    docs.each { |doc| index.index(id: doc[:id], body: doc) }
    wait_for_documents(index, expected_count: 10)
    
    # Search
    results = index.search(body: { query: { match_all: {} } })
    expect(results["hits"]["total"]["value"]).to eq(10)
  end
end
```

## Resources

- Full documentation: `INTEGRATION_TESTS.md`
- Test README: `spec/integration/README.md`
- Integration test plan: `INTEGRATION_TEST_PLAN.md`

