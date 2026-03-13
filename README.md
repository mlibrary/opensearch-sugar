# Opensearch::Sugar

A little syntactic sugar on top of the official OpenSearch ruby gem.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'opensearch-sugar'
```

And then execute:

```bash
bundle install
```

## Testing

This gem includes a comprehensive integration test suite that runs against a real OpenSearch instance.

### Running Tests

```bash
# Start OpenSearch
docker-compose up -d

# Run integration tests
./run-integration-tests.sh

# Or manually
RUN_INTEGRATION_TESTS=true bundle exec rake integration

# Run only unit tests
bundle exec rake unit
```

### Test Documentation

- **[INTEGRATION_TESTS_QUICKREF.md](INTEGRATION_TESTS_QUICKREF.md)** - Quick reference for running tests
- **[INTEGRATION_TESTS.md](INTEGRATION_TESTS.md)** - Complete test documentation
- **[spec/integration/README.md](spec/integration/README.md)** - Integration test guide
- **[CHECKLIST.md](CHECKLIST.md)** - Implementation checklist

The test suite includes 64+ examples covering:
- Client operations and configuration
- Index lifecycle management
- Document CRUD operations
- Search queries and aggregations
- Bulk operations
- Error handling

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/billdueber/opensearch-sugar.
