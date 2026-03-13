# Integration Test Suite
This directory contains integration tests for the OpenSearch::Sugar gem that test against a real OpenSearch instance.
## Prerequisites
- Docker and Docker Compose installed
- OpenSearch instance running (via docker-compose or standalone)
## Running Tests
### 1. Start OpenSearch
```bash
docker-compose up -d
```
Wait for OpenSearch to be ready (check with `docker-compose logs -f` until you see "Node started").
### 2. Run Integration Tests
```bash
# Run all integration tests
RUN_INTEGRATION_TESTS=true bundle exec rspec spec/integration
# Run specific test file
RUN_INTEGRATION_tests=true bundle exec rspec spec/integration/client_spec.rb
# Run with verbose output
RUN_INTEGRATION_TESTS=true bundle exec rspec spec/integration --format documentation
```
### 3. Environment Variables
You can customize the test environment with these variables:
- `OPENSEARCH_URL`: OpenSearch endpoint (default: `http://localhost:9200`)
- `OPENSEARCH_USER`: Username (default: `admin`)
- `OPENSEARCH_PASSWORD`: Password (default: `admin`)
- `RUN_INTEGRATION_TESTS`: Must be set to run integration tests
Example:
```bash
OPENSEARCH_URL=http://localhost:9200 \
OPENSEARCH_USER=admin \
OPENSEARCH_PASSWORD=mypassword \
RUN_INTEGRATION_TESTS=true \
bundle exec rspec spec/integration
```
## Test Structure
- `client_spec.rb`: Tests for OpenSearch::Sugar::Client
  - Connection and initialization
  - Cluster operations
  - Index management
  - Bulk operati  - Bulk operati  - Bulk o  - CAT API
  - Templates
  - Error handling
- `index_spec.rb`: Tests for OpenSearch::Sugar::Index
  - Index lifecycle (create, delete, exists)
  - Document CRUD operations
  - Bulk operations
  - Search queries (match, term, range, bool)
  - Aggregations (terms, stats, range, nested)
  - Index management (refresh, flush, settings, mappings)
  - Count operations
  - Scroll API
  - Multi-get
  - Error handling
## Test Helpers
The `spec/support/integration_helper.rb` module provides:
- `test_client`: Create a configured OpenSearch client
- `test_index_name`: Generate unique test index names
- `create_test_index`: Create a test index with optional settings/mappings
- `generate_document`: Generate realistic test documents using Faker
- `generate_documents`: Generate multiple test docu- `gen- `wait_for_index`: Wait for index to be ready
- `wait_for_documents`: Wait for documents to be searchable
- `cleanup_test_indices`: Remove test indices
- `book_mapping`: Sample mapping for test documents
- `standard_settings`: Standard index settings
## Cleanup
Tests automatically clean up after themselves:
1. Each test cleans up its indices in an `after` hook
2. A suite-level cleanup removes any2. A suite test indices
Test indices are prefixed with `test_opensearch_sugar_` for easy identification.
## Retry Logic
Integration tests use `rspec-retry` to handle:
- Network transient failures (3 retries)
- Search eventual consistency (5 retries)
- Cluster operations (3 retries with longer wait)
## Tips
- Tests create unique index names to avoid conflicts
- All test indices are prefixed with `test_opensearch_sugar_`
- Tests use minimal shard/replica counts for speed
- Refresh intervals are set to 1s for faster test feedback
- Use `:retry_on_search` tag for tests sensitive to eventual consistency
## Troubleshooting
**Tests are skipped:**
- Make sure `RUN_INTEGRATION_TESTS=true` is set
- Verify OpenSearch is running and accessible
**Connection errors:**
- Check OpenSearch is running: `docker-compose ps`
- Check logs: `docker-compose logs opensearch`
- Verify environment variables match your setup
**Flaky tests:**
- Some tests may be sensitive to timing; retry logic should handle this
- If tests consistently fail, there may be a real issue
**Cleanup issues:**
- Manually delete test indices: `curl -X DELETE "http://localhost:9200/test_opensearch_sugar_*"`
