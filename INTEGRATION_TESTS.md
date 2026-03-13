# OpenSearch Sugar Integration Test Suite

This document describes the comprehensive integration test suite for the OpenSearch::Sugar gem.

## Overview

The integration test suite validates the functionality of the OpenSearch::Sugar gem against a real OpenSearch instance. It covers all major features including:

- Client initialization and configuration
- Cluster operations
- Index lifecycle management
- Document CRUD operations
- Bulk operations
- Search queries (match, term, range, bool)
- Aggregations (terms, stats, range, nested)
- Index management (settings, mappings, refresh, flush)
- Scroll API
- Multi-get operations
- Error handling

## Test Structure

```
spec/
├── integration/
│   ├── README.md           # Integration test documentation
│   ├── client_spec.rb      # Tests for OpenSearch::Sugar::Client
│   └── index_spec.rb       # Tests for OpenSearch::Sugar::Index
├── support/
│   ├── integration_helper.rb  # Helpers for integration tests
│   └── retry_config.rb        # Retry configuration for flaky tests
└── spec_helper.rb          # Main RSpec configuration
```

## Running the Tests

### Prerequisites

1. Docker and Docker Compose installed
2. OpenSearch instance running (or use the included docker-compose setup)

### Quick Start

```bash
# Start OpenSearch
docker-compose up -d

# Run all integration tests
./run-integration-tests.sh

# Or manually
RUN_INTEGRATION_TESTS=true bundle exec rake integration
```

### Using Rake Tasks

```bash
# Run only unit tests
bundle exec rake unit

# Run integration tests
bundle exec rake integration

# Run all tests (unit only by default)
bundle exec rake
```

### Environment Variables

Configure the test environment with these variables:

```bash
OPENSEARCH_URL=http://localhost:9200
OPENSEARCH_USER=admin
OPENSEARCH_PASSWORD=admin
RUN_INTEGRATION_TESTS=true
```

## Test Coverage

### Client Tests (89 examples)

#### Initialization and Connection (5 examples)
- Client creation with URL only
- Client creation with authentication
- Ping OpenSearch
- Retrieve cluster info
- Handle connection errors

#### Cluster Operations (3 examples)
- Retrieve cluster health
- Retrieve cluster stats
- List nodes

#### Index Operations (3 examples)
- Create Index instance
- List indices
- Create multiple indices

#### Bulk Operations (2 examples)
- Perform bulk indexing
- Handle bulk errors

#### Search Operations (3 examples)
- Search across all indices
- Search with size limit
- Search with aggregations

#### CAT API Operations (3 examples)
- List indices with CAT API
- Show allocation
- Show shards

#### Template Operations (2 examples)
- Create index template
- Retrieve index template

#### Snapshot Operations (1 example)
- List snapshot repositories

#### Error Handling (2 examples)
- Handle non-existent index operations
- Handle malformed queries

### Index Tests (126 examples)

#### Index Lifecycle (6 examples)
- Create new index
- Create index with settings
- Create index with mappings
- Create index with both settings and mappings
- Delete index
- Handle creating existing index

#### Document Operations (6 examples)
- Index document with auto-generated ID
- Index document with specified ID
- Update existing document
- Retrieve document by ID
- Delete document by ID
- Update document using update API

#### Bulk Operations (2 examples)
- Perform bulk indexing (50 documents)
- Perform bulk operations with mixed actions

#### Search Operations (8 examples)
- Search with match_all query
- Search with term query
- Search with match query
- Search with range query
- Search with bool query
- Search with pagination
- Search with sorting
- Search with source filtering

#### Aggregations (4 examples)
- Terms aggregation
- Stats aggregation
- Range aggregation
- Nested aggregations

#### Index Management (8 examples)
- Refresh index
- Flush index
- Retrieve index stats
- Retrieve index settings
- Retrieve index mappings
- Update index settings
- Close and open index

#### Count Operations (2 examples)
- Count all documents
- Count with query

#### Scroll API (1 example)
- Scroll through all documents (100 documents)

#### Multi-get Operations (1 example)
- Retrieve multiple documents by IDs

#### Error Handling (3 examples)
- Handle get on non-existent document
- Handle delete on non-existent document
- Handle operations on non-existent index

## Test Helpers

### IntegrationHelper Module

Provides utilities for integration testing:

#### Client Management
- `test_client` - Get configured OpenSearch client
- `opensearch_available?` - Check if OpenSearch is reachable
- `cluster_health` - Get cluster health status

#### Index Management
- `test_index_name(base_name)` - Generate unique test index names
- `create_test_index(name, settings:, mappings:)` - Create test index
- `cleanup_test_indices` - Remove all test indices

#### Data Generation
- `generate_document(overrides)` - Generate realistic test documents using Faker
- `generate_documents(count, &block)` - Generate multiple documents
- `book_mapping` - Sample mapping for book documents
- `standard_settings(shards:, replicas:)` - Standard index settings

#### Synchronization
- `wait_for_index(index_name, timeout:)` - Wait for index to be ready
- `wait_for_documents(index, expected_count:, timeout:)` - Wait for documents to be searchable

#### Utilities
- `retry_on_failure(max_attempts:, delay:, &block)` - Retry helper for flaky operations

### Retry Configuration

Integration tests use `rspec-retry` to handle transient failures:

- **Default (all integration tests)**: 3 retries with 1s wait
- **Search operations** (`:retry_on_search` tag): 5 retries with 0.5s wait
- **Cluster operations** (`:retry_on_cluster` tag): 3 retries with 2s wait

## Test Data

Tests use Faker to generate realistic book-related data:

```ruby
{
  id: "uuid",
  title: "Book Title",
  author: "Author Name",
  genre: "Fiction",
  publisher: "Publisher Name",
  isbn: "1234567890",
  price: 29.99,
  publish_date: "2020-01-01",
  description: "Lorem ipsum...",
  rating: 4.5,
  pages: 350,
  available: true,
  tags: ["tag1", "tag2"],
  created_at: "2024-01-01T00:00:00Z"
}
```

## Cleanup Strategy

Tests automatically clean up after themselves to prevent pollution:

1. **Per-test cleanup**: Each test cleans up its indices in an `after` hook
2. **Suite-level cleanup**: A final cleanup removes any remaining test indices
3. **Naming convention**: All test indices are prefixed with `test_opensearch_sugar_`
4. **Manual cleanup**: `curl -X DELETE "http://localhost:9200/test_opensearch_sugar_*"`

## Performance Optimization

The test suite is optimized for speed:

- **Minimal shards/replicas**: Tests use 1 shard, 0 replicas
- **Fast refresh**: Refresh interval set to 1s
- **Bulk operations**: Large datasets use bulk indexing
- **Parallel-safe**: Tests use unique index names to avoid conflicts
- **Smart waiting**: Tests wait only as long as needed for operations to complete

## Best Practices

### Adding New Tests

1. **Use helpers**: Leverage `integration_helper` methods
2. **Clean up**: Ensure tests clean up after themselves
3. **Unique names**: Use `test_index_name` for index names
4. **Wait appropriately**: Use `wait_for_index` and `wait_for_documents`
5. **Tag properly**: Use `:retry_on_search` for search-dependent tests
6. **Document intent**: Add clear descriptions to test cases

### Handling Flaky Tests

1. **Add retry tags**: Use `:retry_on_search` or `:retry_on_cluster`
2. **Increase wait times**: Adjust `wait_for_documents` timeout
3. **Check timing**: Ensure proper synchronization
4. **Isolate issues**: Run test individually to verify flakiness

### Debugging Tests

```bash
# Run specific test file
RUN_INTEGRATION_TESTS=true bundle exec rspec spec/integration/client_spec.rb

# Run specific test
RUN_INTEGRATION_TESTS=true bundle exec rspec spec/integration/client_spec.rb:25

# Verbose output
RUN_INTEGRATION_TESTS=true bundle exec rspec spec/integration --format documentation

# Check OpenSearch logs
docker-compose logs -f opensearch
```

## Docker Integration

The test suite works seamlessly with the included Docker configuration:

### Using docker-compose

```bash
# Start OpenSearch
docker-compose up -d opensearch

# Wait for health check
docker-compose ps

# Run tests in host environment
RUN_INTEGRATION_TESTS=true bundle exec rake integration

# Or run tests in container
docker-compose run test bundle exec rspec spec/integration
```

### Using the test script

```bash
# Automatically starts OpenSearch, runs tests, and cleans up
./run-integration-tests.sh

# Keep OpenSearch running after tests
KEEP_RUNNING=true ./run-integration-tests.sh

# Skip Docker startup (use existing OpenSearch)
SKIP_DOCKER=true ./run-integration-tests.sh
```

## Continuous Integration

### GitHub Actions Example

```yaml
name: Integration Tests

on: [push, pull_request]

jobs:
  integration:
    runs-on: ubuntu-latest
    
    services:
      opensearch:
        image: opensearchproject/opensearch:latest
        env:
          discovery.type: single-node
          DISABLE_SECURITY_PLUGIN: true
        ports:
          - 9200:9200
    
    steps:
      - uses: actions/checkout@v3
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.4
          bundler-cache: true
      
      - name: Wait for OpenSearch
        run: |
          timeout 60 bash -c 'until curl -f http://localhost:9200; do sleep 2; done'
      
      - name: Run integration tests
        env:
          RUN_INTEGRATION_TESTS: true
          OPENSEARCH_URL: http://localhost:9200
        run: bundle exec rake integration
```

## Troubleshooting

### Tests are skipped
- Ensure `RUN_INTEGRATION_TESTS=true` is set
- Verify OpenSearch is running and accessible

### Connection errors
- Check OpenSearch status: `docker-compose ps`
- View logs: `docker-compose logs opensearch`
- Verify environment variables match your setup

### Timeout errors
- Increase wait timeouts in helper methods
- Check OpenSearch resource allocation
- Verify network connectivity

### Flaky tests
- Tests use retry logic; consistent failures indicate real issues
- Check for proper synchronization with `wait_for_documents`
- Ensure unique test data to avoid conflicts

### Cleanup issues
- Manually delete test indices: `curl -X DELETE "http://localhost:9200/test_opensearch_sugar_*"`
- Check for orphaned scroll contexts
- Verify index deletion permissions

## Future Enhancements

Potential improvements to the test suite:

1. **Additional test coverage**
   - Pipeline operations
   - Index aliases
   - Reindexing operations
   - Percolator queries

2. **Performance testing**
   - Benchmark bulk indexing speeds
   - Measure search query performance
   - Test with larger datasets

3. **Error scenario coverage**
   - Network failures
   - Disk space issues
   - Cluster health degradation

4. **Multi-node testing**
   - Test with multiple OpenSearch nodes
   - Verify shard allocation
   - Test failover scenarios

## Summary

The integration test suite provides comprehensive coverage of the OpenSearch::Sugar gem's functionality. It uses modern Ruby testing practices, handles eventual consistency gracefully, and cleans up after itself. The suite is optimized for both local development and CI environments.

**Total Test Count**: ~215 examples  
**Execution Time**: ~30-60 seconds (depending on hardware)  
**Coverage**: All major OpenSearch operations  
**Reliability**: Retry logic handles transient failures  
**Maintainability**: Helpers reduce duplication and improve clarity

