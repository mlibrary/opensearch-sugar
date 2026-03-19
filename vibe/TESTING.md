# Integration Testing - Quick Reference

This guide shows how to run integration tests that automatically execute inside the ruby container.

## Prerequisites

- Docker and Docker Compose installed
- No need to have Ruby installed on host (tests run in container)

## Quick Start

```bash
# Run all integration tests (starts containers automatically)
rake test_integration

# Or use the shell script
./bin/run-integration-tests.sh
```

That's it! The tests will:
1. Start the opensearch container
2. Wait for it to be healthy
3. Start the ruby container
4. Run all integration tests inside the ruby container
5. Report results to your terminal

## Available Commands

### Running Tests

```bash
# Run all integration tests in container
rake test_integration

# Run both unit tests (host) and integration tests (container)
rake test

# Run only unit tests on host
rake spec

# Run specific integration test file in container
rake docker:rspec["spec/integration/client_spec.rb"]

# Run specific test by line number in container
rake docker:rspec["spec/integration/index_spec.rb:42"]

# Run tests with specific tag in container
rake docker:rspec["--tag aliases"]
```

### Managing Containers

```bash
# Start OpenSearch only (useful for development)
rake docker:start

# Stop all containers
rake docker:stop

# Restart OpenSearch
rake docker:restart

# View logs (follows, use Ctrl+C to exit)
rake docker:logs

# Rebuild containers after Dockerfile changes
rake docker:build

# Force rebuild without cache
rake docker:rebuild
```

### Interactive Development

```bash
# Open a shell in the ruby container
rake docker:shell

# Open a console (pry/irb) with test environment loaded
rake docker:console
# Inside the console, you can:
# > client = OpenSearch::Sugar.client
# > client.index_names
# > index = client.open_or_create("test_index")
```

## Environment Variables

### For Running Tests

Set these before running tests to control behavior:

```bash
# Enable verbose logging
OPENSEARCH_LOG=true rake test_integration

# Enable request tracing
OPENSEARCH_TRACE=true rake test_integration

# Increase timeout for slow environments
OPENSEARCH_TIMEOUT=30 rake test_integration

# Reduce retries for faster failures
OPENSEARCH_RETRY_COUNT=2 rake test_integration

# Keep Docker running after tests (for debugging)
KEEP_RUNNING=true ./bin/run-integration-tests.sh
```

### For Container Configuration

These are set in `env.test` and automatically loaded in containers:

```bash
OPENSEARCH_HOST=https://opensearch:9200
OPENSEARCH_USER=admin
OPENSEARCH_PASSWORD=WD71969!Bill
OPENSEARCH_INITIAL_ADMIN_PASSWORD=WD71969!Bill
```

## Test Structure

All integration tests:
- Are tagged with `integration: true`
- Run inside the ruby Docker container
- Connect to opensearch via Docker network
- Create uniquely named indexes (with timestamps)
- Clean up after themselves automatically
- Use real OpenSearch (no mocks)

## Troubleshooting

### "Could not find ffi gem"

```bash
# Rebuild the ruby container
rake docker:rebuild
```

### "OpenSearch is not available"

```bash
# Check OpenSearch status
docker compose ps opensearch

# View OpenSearch logs
rake docker:logs

# Restart OpenSearch
rake docker:restart
```

### "Tests fail with connection error"

```bash
# Verify opensearch is healthy
docker compose ps

# Check health check
docker compose exec opensearch curl -sku admin:WD71969!Bill https://localhost:9200/_cluster/health

# Verify ruby container can reach opensearch
docker compose exec ruby curl -sku admin:WD71969!Bill https://opensearch:9200
```

### "Permission denied" errors

The ruby container runs as UID/GID 1000. If you see permission errors:

```bash
# Check file permissions
ls -la

# If needed, adjust ownership
sudo chown -R 1000:1000 .
```

## Writing New Tests

1. Create a new spec file in `spec/integration/`
2. Require `integration_helper` at the top
3. Tag the describe block with `integration: true`
4. Use `create_test_index` helper for test indexes
5. Tests will automatically run in container

Example:

```ruby
require "integration_helper"

RSpec.describe "My Feature", integration: true do
  it "does something" do
    index = create_test_index("test_my_feature_#{Time.now.to_i}")
    # Test your feature
    expect(index).to be_a(OpenSearch::Sugar::Index)
  end
end
```

Run it:
```bash
rake docker:rspec["spec/integration/my_feature_spec.rb"]
```

## CI/CD Integration

For GitHub Actions or similar CI systems:

```yaml
- name: Run integration tests
  run: rake test_integration
```

The containerized approach ensures tests run identically in CI and locally.

