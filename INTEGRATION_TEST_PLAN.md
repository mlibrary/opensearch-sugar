# OpenSearch::Sugar Integration Test Suite - Implementation Plan

## Overview

This document outlines a comprehensive RSpec integration test suite for the OpenSearch::Sugar gem that:
- Tests against a real OpenSearch deployment (via Docker)
- Exercises all non-trivial functionality
- Uses VCR selectively for deterministic operations
- Cleans up all test data
- Provides clear documentation and examples

---

## Table of Contents

1. [Test Infrastructure Setup](#test-infrastructure-setup)
2. [Test Organization](#test-organization)
3. [VCR Configuration](#vcr-configuration)
4. [Test Helpers and Utilities](#test-helpers-and-utilities)
5. [Test Coverage Plan](#test-coverage-plan)
6. [Cleanup Strategy](#cleanup-strategy)
7. [CI/CD Integration](#cicd-integration)
8. [Open Questions & Decisions](#open-questions--decisions)

---

## Test Infrastructure Setup

### Directory Structure

```
spec/
├── spec_helper.rb                    # RSpec configuration
├── support/
│   ├── opensearch_helpers.rb         # Connection and cleanup helpers
│   ├── vcr.rb                         # VCR configuration
│   ├── shared_contexts.rb             # Shared test contexts
│   ├── shared_examples.rb             # Shared example groups
│   └── test_data_factory.rb          # Test data generation
├── integration/
│   ├── client_spec.rb                 # Client integration tests
│   ├── index_spec.rb                  # Index integration tests
│   ├── models_spec.rb                 # ML Models integration tests
│   ├── document_operations_spec.rb    # Document CRUD tests
│   ├── search_spec.rb                 # Search functionality tests
│   ├── analyzer_spec.rb               # Analyzer tests
│   └── pipeline_spec.rb               # Pipeline tests
├── fixtures/
│   ├── vcr_cassettes/                 # VCR recordings
│   ├── test_documents.jsonl           # Sample JSONL for bulk indexing
│   └── test_settings/                 # Various index settings configs
└── docker/
    └── wait-for-opensearch.rb         # Script to wait for OpenSearch readiness
```

### Required Gems

```ruby
# Gemfile additions
group :test do
  gem 'rspec', '~> 3.13'
  gem 'vcr', '~> 6.2'              # HTTP recording
  gem 'webmock', '~> 3.23'         # HTTP stubbing (required by VCR)
  gem 'faker', '~> 3.4'            # Test data generation
  gem 'factory_bot', '~> 6.4'     # Test data factories (optional)
  gem 'rspec-retry', '~> 0.6'     # Retry flaky tests (for integration)
  gem 'database_cleaner', '~> 2.0' # Cleanup patterns (optional)
  gem 'timecop', '~> 0.9'         # Time manipulation for tests
end
```

### spec_helper.rb Configuration

**Key Requirements:**
- Wait for OpenSearch to be ready before running tests
- Configure VCR with appropriate matchers
- Set up cleanup hooks
- Configure RSpec for integration testing
- Handle logging appropriately

**Sections:**
```ruby
# 1. Require necessary libraries
# 2. Load support files
# 3. Wait for OpenSearch readiness
# 4. Configure RSpec
#    - Use :context metadata for VCR
#    - Set up around hooks for cleanup
#    - Configure retry for flaky integration tests
# 5. Configure VCR (see VCR section)
# 6. Set up shared test client
```

---

## Test Organization

### Test Grouping Strategy

**By Functionality:**
- Client operations (cluster-level)
- Index management (lifecycle, settings, mappings)
- Document operations (CRUD, bulk)
- Search operations
- Analyzer operations
- ML Model operations
- Pipeline operations

**Test Metadata:**
```ruby
# Use metadata for test categorization
describe "Something", :integration do          # All integration tests
describe "Something", :vcr do                  # Use VCR for this test
describe "Something", :cleanup_required do     # Needs special cleanup
describe "Something", :flaky do                # Known to be flaky, retry
describe "Something", :slow do                 # Long-running test
```

### Shared Examples

**Create shared examples for common patterns:**

```ruby
# shared_examples_for "an index operation"
# shared_examples_for "a document operation"
# shared_examples_for "a destructive operation"
# shared_examples_for "a method that validates input"
# shared_examples_for "a method that requires an existing index"
```

### Shared Contexts

**Common test contexts:**

```ruby
# shared_context "with a test index"
# shared_context "with documents"
# shared_context "with custom analyzers"
# shared_context "with ML model"
# shared_context "with pipeline"
```

---

## VCR Configuration

### VCR Strategy

**Use VCR ONLY for:**
1. ✅ Cluster info/health checks (deterministic)
2. ✅ Listing analyzers (deterministic for same version)
3. ✅ ML model registration responses (same model = same response)
4. ✅ Schema validation operations (deterministic)
5. ✅ Error responses from invalid operations (deterministic)

**DO NOT use VCR for:**
1. ❌ Document indexing (IDs, timestamps vary)
2. ❌ Search results (scoring, timing varies)
3. ❌ Document counts (state-dependent)
4. ❌ Index creation/deletion (state-changing)
5. ❌ Anything with auto-generated IDs or timestamps

### VCR Configuration Details

```ruby
# support/vcr.rb

VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!
  
  # Ignore OpenSearch cluster UUID (changes per deployment)
  c.filter_sensitive_data('<CLUSTER_UUID>') do |interaction|
    # Extract and replace cluster UUID from responses
  end
  
  # Ignore timestamps in responses
  c.filter_sensitive_data('<TIMESTAMP>') do |interaction|
    # Replace timestamp fields
  end
  
  # Match requests by method and URI (ignore body for some operations)
  c.default_cassette_options = {
    match_requests_on: [:method, :uri],
    record: :once,
    allow_playback_repeats: true
  }
  
  # Custom matcher for OpenSearch requests
  # (ignore certain dynamic parameters)
end
```

### VCR Usage Pattern

```ruby
# In tests:
describe "something deterministic", :vcr do
  it "does something" do
    # VCR will record/playback automatically
  end
end

# With custom cassette:
it "does something", vcr: { cassette_name: "custom_name" } do
  # ...
end

# Turn off VCR when not needed:
it "does something live", vcr: false do
  # Always hits real OpenSearch
end
```

### 🤔 **DECISION NEEDED: VCR Matching Strategy**

**Options:**
1. **Match on method + URI only** - Fast, but may miss parameter differences
2. **Match on method + URI + body** - More accurate, but fails on dynamic data
3. **Custom matcher** - Ignore dynamic fields (timestamps, IDs) in body
4. **Hybrid** - Different strategies for different operation types

**Recommendation:** Option 3 (custom matcher) for most operations, with specific matchers for ML models, analyzers, etc.

---

## Test Helpers and Utilities

### OpenSearch Helpers (`support/opensearch_helpers.rb`)

**Required Helper Methods:**

```ruby
module OpenSearchHelpers
  # Connection
  def test_client(logger: nil)
  def wait_for_opensearch(timeout: 60)
  def opensearch_version
  
  # Index Management
  def create_test_index(name, **options)
  def delete_test_index(name)
  def list_test_indices  # Only indices created by tests
  def cleanup_all_test_indices
  
  # Document Helpers
  def index_test_document(index:, doc:, id: nil, refresh: true)
  def index_test_documents(index:, documents:, refresh: true)
  def delete_all_test_documents(index:)
  
  # Wait Helpers
  def wait_for_index_ready(index_name, timeout: 30)
  def wait_for_document_count(index:, count:, timeout: 10)
  def wait_for_refresh(index:)
  
  # Test Data
  def generate_test_index_name(prefix: "test")
  def generate_test_document(overrides = {})
  
  # Assertions
  def expect_index_to_exist(name)
  def expect_index_not_to_exist(name)
  def expect_document_count(index:, count:)
  
  # Cleanup Tracking
  def track_test_index(name)
  def tracked_test_indices
end
```

### Test Data Factory (`support/test_data_factory.rb`)

**Generate consistent test data:**

```ruby
module TestDataFactory
  # Documents
  def build_product_document(**attrs)
  def build_user_document(**attrs)
  def build_article_document(**attrs)
  
  # Settings
  def build_analyzer_settings(type: :standard)
  def build_knn_settings(dimension: 128)
  
  # Mappings
  def build_text_mappings(**fields)
  def build_knn_mappings(**fields)
  
  # JSONL
  def generate_jsonl_file(documents:, path:)
end
```

### Cleanup Helpers

**Ensure no test data persists:**

```ruby
module CleanupHelpers
  # Before suite
  def ensure_clean_slate
  
  # After each test
  def cleanup_test_resources
  
  # After suite
  def verify_no_test_artifacts
end
```

---

## Test Coverage Plan

### 1. Client Integration Tests (`spec/integration/client_spec.rb`)

**Test Coverage:**

```ruby
describe OpenSearch::Sugar::Client, :integration do
  # Initialization
  describe "#initialize" do
    context "with default settings" do
      # ✅ Connects to OpenSearch
      # ✅ Creates Models instance
      # ✅ Logs initialization
    end
    
    context "with custom settings" do
      # ✅ Respects custom host
      # ✅ Respects custom timeout
      # ✅ Respects custom logger
    end
    
    context "with invalid settings" do
      # ✅ Handles connection errors gracefully
    end
  end
  
  # Cluster operations
  describe "#set_log_level", :vcr do
    # ✅ Sets log level successfully
    # ✅ Validates log level
    # ✅ Raises error for invalid level
  end
  
  # Index existence
  describe "#index_exists?" do
    # ✅ Returns true for existing index
    # ✅ Returns false for non-existent index
    # ✅ Alias: #has_index?
  end
  
  # Index listing
  describe "#index_names" do
    # ✅ Returns empty array when no indices
    # ✅ Returns list of index names
    # ✅ Handles errors gracefully
  end
  
  # Index access
  describe "#[]" do
    # ✅ Returns Index instance for existing index
    # ✅ Raises ArgumentError for non-existent index
  end
  
  # Index creation
  describe "#create_index" do
    # ✅ Creates index with default settings
    # ✅ Creates index with k-NN enabled
    # ✅ Creates index with custom settings
    # ✅ Raises error if index exists
  end
  
  # Index open or create
  describe "#open_or_create" do
    # ✅ Opens existing index
    # ✅ Creates new index if doesn't exist
    # ✅ Respects k-NN setting
    # ✅ Respects custom settings
  end
end
```

**VCR Usage:**
- ✅ Use VCR for `set_log_level` (deterministic cluster setting)
- ❌ Don't use VCR for index operations (state-changing)

### 2. Index Integration Tests (`spec/integration/index_spec.rb`)

**Test Coverage:**

```ruby
describe OpenSearch::Sugar::Index, :integration do
  # Factory methods
  describe ".open" do
    # ✅ Opens existing index
    # ✅ Raises ArgumentError for non-existent
    # ✅ Validates parameters
  end
  
  describe ".create" do
    # ✅ Creates index with defaults
    # ✅ Creates with k-NN enabled
    # ✅ Creates with custom settings
    # ✅ Raises error if exists
  end
  
  describe ".open_or_create" do
    # ✅ Opens if exists
    # ✅ Creates if doesn't exist
  end
  
  describe ".exists?" do
    # ✅ Returns true for existing
    # ✅ Returns false for non-existent
  end
  
  # Settings operations
  describe "#update_settings" do
    # ✅ Updates analyzer settings
    # ✅ Closes and reopens index
    # ✅ Returns success status
    # ✅ Handles errors gracefully
    # ✅ Validates settings hash
    # 🤔 Test with various setting types (analysis, refresh, etc.)
  end
  
  describe "#settings", :vcr do
    # ✅ Returns current settings
    # ✅ Includes default settings
  end
  
  # Mappings operations
  describe "#update_mappings" do
    # ✅ Adds new field mappings
    # ✅ Doesn't require index closure (modern OpenSearch)
    # ✅ Returns success status
    # ✅ Handles errors gracefully
    # ✅ Validates mappings hash
  end
  
  describe "#mappings", :vcr do
    # ✅ Returns current mappings
    # ✅ Shows all properties
  end
  
  # Lifecycle
  describe "#delete!" do
    # ✅ Deletes the index
    # ✅ Index no longer exists after deletion
  end
  
  # Document counting
  describe "#count" do
    # ✅ Returns 0 for empty index
    # ✅ Returns accurate count
    # ✅ Updates after refresh
  end
  
  # Aliases
  describe "#aliases" do
    # ✅ Returns empty array for no aliases
    # ✅ Returns list of aliases
  end
  
  describe "#create_alias" do
    # ✅ Creates alias successfully
    # ✅ Alias appears in #aliases
    # ✅ Validates alias name
  end
  
  # Analyzers
  describe "#all_available_analyzers", :vcr do
    # ✅ Returns built-in analyzers
    # ✅ Returns custom analyzers
    # ✅ Returns cluster-level analyzers
    # ✅ Alias: #analyzers
  end
  
  describe "#analyze_text" do
    # ✅ Analyzes text with standard analyzer
    # ✅ Analyzes text with custom analyzer
    # ✅ Returns array of tokens
    # ✅ Raises error for non-existent analyzer
  end
  
  describe "#analyze_text_field" do
    # ✅ Uses field's analyzer
    # ✅ Raises error for non-existent field
    # ✅ Raises error if no analyzer specified
  end
  
  # Document operations (see separate section)
end
```

**VCR Usage:**
- ✅ Use VCR for `#settings` (mostly deterministic)
- ✅ Use VCR for `#mappings` (deterministic)
- ✅ Use VCR for `#all_available_analyzers` (deterministic per version)
- ❌ Don't use VCR for count, aliases (state-dependent)

### 3. Document Operations Tests (`spec/integration/document_operations_spec.rb`)

**Test Coverage:**

```ruby
describe "Document Operations", :integration do
  # Single document indexing
  describe "#index_document" do
    # ✅ Indexes document with auto-generated ID
    # ✅ Indexes document with specified ID
    # ✅ Updates existing document
    # ✅ With refresh: true, document is immediately searchable
    # ✅ With refresh: false, document may not be immediately searchable
    # ✅ Validates document is a Hash
  end
  
  # Bulk indexing from JSONL
  describe "#index_jsonl" do
    # ✅ Indexes all documents from file
    # ✅ Uses id_field parameter for document IDs
    # ✅ Handles empty file
    # ✅ Raises error for non-existent file
    # ✅ Raises error for invalid JSON
    # ✅ Returns bulk response with item count
    # ✅ With refresh: true, all documents searchable
  end
  
  # Document deletion
  describe "#delete_by_id" do
    # ✅ Deletes existing document
    # ✅ Returns deletion response
    # ✅ Raises error for nil ID
    # ✅ Raises error for empty ID
  end
  
  # Clear all documents
  describe "#clear!" do
    # ✅ Deletes all documents
    # ✅ Returns count of deleted documents
    # ✅ Leaves index structure intact
    # ✅ Works with large document counts
  end
end
```

**VCR Usage:**
- ❌ Don't use VCR for any document operations (all state-changing)

### 4. ML Models Integration Tests (`spec/integration/models_spec.rb`)

**Test Coverage:**

```ruby
describe OpenSearch::Sugar::Models, :integration do
  # 🤔 DECISION: ML models require external model files
  # May need to use VCR extensively or skip if no models available
  
  # Model listing
  describe "#list" do
    # ✅ Returns empty array when no models
    # ✅ Returns list of registered models
    # ✅ Caches results by default
    # ✅ With refresh: true, fetches fresh data
  end
  
  # Model search
  describe "#[]" do
    # ✅ Finds by exact name
    # ✅ Finds by ID
    # ✅ Finds by partial name (case-insensitive)
    # ✅ Returns latest version for partial match
    # ✅ Returns nil for non-existent
  end
  
  # Model registration
  describe "#register", :slow do
    # ✅ Registers new model
    # ✅ Returns existing if already registered
    # ✅ Polls until completion
    # ✅ Respects poll_interval parameter
    # ✅ Respects timeout parameter
    # ✅ Raises ModelRegistrationError on failure
    # ✅ Raises ModelRegistrationTimeoutError on timeout
    # 🤔 Requires actual model file - may need to mock
  end
  
  # Deployment status
  describe "#deployed?" do
    # ✅ Returns true for deployed model
    # ✅ Returns false for undeployed model
    # ✅ Returns false for non-existent model
  end
  
  describe "#ensure_deployed!" do
    # ✅ Returns immediately if already deployed
    # ✅ Deploys model if not deployed
    # ✅ Waits for deployment completion
    # ✅ Respects timeout
  end
  
  # Model undeployment
  describe "#undeploy!" do
    # ✅ Undeploys model successfully
    # ✅ Raises ModelNotFoundError for non-existent
  end
  
  # Model deletion
  describe "#delete!" do
    # ✅ Undeploys then deletes model
    # ✅ Raises ModelNotFoundError for non-existent
  end
  
  # Pipeline creation
  describe "#create_pipeline" do
    # ✅ Creates text embedding pipeline
    # ✅ Uses correct model ID
    # ✅ Creates copy processors
    # ✅ Sanitizes pipeline name
    # ✅ Raises ModelNotFoundError for non-existent model
  end
end
```

**VCR Usage:**
- ✅ Use VCR for model listing (if deterministic)
- 🤔 Complex decision for registration - may need VCR + mocking
- ❌ Don't use VCR for deployment status (state-dependent)

**🤔 DECISION NEEDED: ML Model Testing Strategy**

**Options:**
1. **Use pre-registered models in test cluster** - Requires setup
2. **Use VCR with pre-recorded model operations** - Fast but not truly integration
3. **Skip ML tests if no models available** - Simple but incomplete
4. **Use small test model (e.g., sentence transformers)** - Real but slow

**Recommendation:** Option 1 (pre-registered test models) + Option 3 (skip if unavailable) with `skip "ML models not available"` guard.

### 5. Analyzer Integration Tests (`spec/integration/analyzer_spec.rb`)

**Test Coverage:**

```ruby
describe "Analyzer Operations", :integration do
  describe "built-in analyzers", :vcr do
    # ✅ Standard analyzer tokenizes correctly
    # ✅ Simple analyzer tokenizes correctly
    # ✅ Whitespace analyzer tokenizes correctly
  end
  
  describe "custom analyzers" do
    # ✅ Custom analyzer defined in settings works
    # ✅ Token filters apply correctly
    # ✅ Character filters apply correctly
  end
  
  describe "field-specific analyzers" do
    # ✅ Different fields can use different analyzers
    # ✅ analyze_text_field uses correct analyzer
  end
  
  describe "ICU plugin analyzers", :vcr do
    # ✅ ICU tokenizer available (from Docker setup)
    # ✅ ICU normalizer available
    # 🤔 Test if plugin is actually installed
  end
end
```

**VCR Usage:**
- ✅ Use VCR for built-in analyzer tests (deterministic)
- ❌ Don't use VCR for custom analyzers (need index setup)

### 6. Error Handling Tests

**Test Coverage:**

```ruby
describe "Error Handling", :integration do
  describe OpenSearch::Sugar::OpenSearchError do
    # ✅ Raised for connection failures
    # ✅ Raised for malformed requests
    # ✅ Includes helpful error message
  end
  
  describe OpenSearch::Sugar::ModelNotFoundError do
    # ✅ Raised when model doesn't exist
    # ✅ Includes model name in message
  end
  
  describe OpenSearch::Sugar::ModelRegistrationError do
    # ✅ Raised when registration fails
    # ✅ Includes error details
  end
  
  describe ArgumentError do
    # ✅ Raised for nil/empty required parameters
    # ✅ Raised for invalid types
    # ✅ Includes parameter name in message
  end
end
```

**VCR Usage:**
- ✅ Use VCR for error responses (deterministic)

---

## Cleanup Strategy

### Before Suite

```ruby
RSpec.configure do |config|
  config.before(:suite) do
    # 1. Wait for OpenSearch to be ready
    wait_for_opensearch(timeout: 60)
    
    # 2. Clean up any leftover test artifacts
    cleanup_all_test_indices
    
    # 3. Verify clean state
    expect(list_test_indices).to be_empty
    
    # 4. Set up test logger (optional)
    # 5. Verify required plugins (ICU, ML)
  end
end
```

### After Each Test

```ruby
RSpec.configure do |config|
  config.after(:each) do |example|
    # 1. Delete test indices created in this test
    if example.metadata[:cleanup_required] != false
      cleanup_test_resources
    end
    
    # 2. Verify no orphaned indices
    # 3. Clear any cached data
  end
end
```

### After Suite

```ruby
RSpec.configure do |config|
  config.after(:suite) do
    # 1. Final cleanup of all test indices
    cleanup_all_test_indices
    
    # 2. Verify no test artifacts remain
    remaining = list_test_indices
    if remaining.any?
      warn "WARNING: Test indices still exist: #{remaining.join(', ')}"
    end
    
    # 3. Close connections
    # 4. Report test coverage (optional)
  end
end
```

### Index Naming Convention

**Use prefix to identify test indices:**

```ruby
TEST_INDEX_PREFIX = "test_opensearch_sugar_"

def generate_test_index_name(suffix = nil)
  suffix ||= SecureRandom.hex(4)
  "#{TEST_INDEX_PREFIX}#{suffix}_#{Time.now.to_i}"
end

def test_index?(name)
  name.start_with?(TEST_INDEX_PREFIX)
end

def cleanup_all_test_indices
  client.index_names.select { |name| test_index?(name) }.each do |name|
    client.indices.delete(index: name)
  rescue => e
    warn "Failed to delete test index #{name}: #{e.message}"
  end
end
```

### Cleanup Verification

```ruby
# Add a final verification test
describe "Cleanup Verification", :cleanup_verification do
  it "leaves no test artifacts", :aggregate_failures do
    # This runs last (use RSpec ordering)
    expect(list_test_indices).to be_empty, 
      "Test indices still exist: #{list_test_indices.join(', ')}"
    
    # Could also check:
    # - No test aliases
    # - No test pipelines
    # - No test models (if applicable)
  end
end
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Integration Tests

on: [push, pull_request]

jobs:
  integration-test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.4
          bundler-cache: true
      
      - name: Start OpenSearch
        run: |
          cp .env.example .env
          docker compose up -d opensearch
          
      - name: Wait for OpenSearch
        run: bundle exec ruby spec/docker/wait-for-opensearch.rb
      
      - name: Run integration tests
        run: bundle exec rspec --tag integration
        env:
          OPENSEARCH_URL: http://localhost:9200
      
      - name: Upload VCR cassettes (if changed)
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: vcr-cassettes
          path: spec/fixtures/vcr_cassettes/
      
      - name: Cleanup
        if: always()
        run: docker compose down -v
```

### Test Execution Options

```bash
# Run all integration tests
bundle exec rspec --tag integration

# Run specific test file
bundle exec rspec spec/integration/client_spec.rb

# Run without VCR (always live)
VCR_OFF=true bundle exec rspec --tag integration

# Re-record all VCR cassettes
VCR_RECORD_MODE=all bundle exec rspec --tag integration

# Run only fast tests
bundle exec rspec --tag integration --tag ~slow

# Run with verbose output
bundle exec rspec --tag integration --format documentation
```

---

## Open Questions & Decisions

### 🤔 **1. VCR vs Live Testing Balance**

**Question:** What percentage of tests should use VCR vs always hit live OpenSearch?

**Options:**
- **Minimal VCR (10-20%):** Only truly deterministic operations
- **Moderate VCR (30-50%):** Most read operations, no writes
- **Heavy VCR (60-80%):** Almost everything, regenerate occasionally

**Recommendation:** Minimal VCR (10-20%) - Integration tests should test integration!

**Rationale:**
- Integration tests are meant to test real behavior
- OpenSearch in Docker is fast enough
- VCR adds complexity and can mask real issues
- Use VCR only for operations that are guaranteed identical

---

### 🤔 **2. ML Model Testing Strategy**

**Question:** How to test ML model functionality without requiring large model files?

**Options:**
1. **Skip if unavailable:** Use `skip unless ml_models_available?`
2. **Mock model responses:** Don't test real ML functionality
3. **Use tiny test model:** Include small model in fixtures
4. **Pre-load in Docker:** Extend Docker image with test model

**Recommendation:** Option 1 (skip if unavailable) + Option 4 (pre-load in Docker image)

**Implementation:**
```ruby
RSpec.configure do |config|
  config.before(:suite) do
    @ml_models_available = test_model_available?
  end
  
  config.around(:each, :requires_ml_model) do |example|
    if @ml_models_available
      example.run
    else
      skip "ML models not available in test environment"
    end
  end
end
```

---

### 🤔 **3. Test Data Volume**

**Question:** How many documents should bulk indexing tests use?

**Options:**
- **Small (10-100 docs):** Fast, but may not catch edge cases
- **Medium (1,000-10,000 docs):** Good balance
- **Large (100,000+ docs):** More realistic, but slow

**Recommendation:** Multiple test cases:
- Default: Medium (1,000 docs)
- Edge case: Small (1 doc)
- Performance: Large (10,000 docs) - marked as `:slow`

---

### 🤔 **4. Flaky Test Handling**

**Question:** How to handle potentially flaky integration tests (timing, eventual consistency)?

**Options:**
1. **Retry with rspec-retry:** Automatically retry failed tests
2. **Wait helpers:** Add explicit waits for consistency
3. **Mark as flaky:** Document known flaky tests
4. **Fail fast:** Don't tolerate any flakiness

**Recommendation:** Option 2 (wait helpers) + Option 1 (retry as backup)

**Implementation:**
```ruby
# Wait helpers
def wait_for_document_count(index:, expected:, timeout: 10)
  Timeout.timeout(timeout) do
    loop do
      actual = index.count
      break if actual == expected
      sleep 0.1
    end
  end
end

# Retry configuration
RSpec.configure do |config|
  config.around(:each, :integration) do |example|
    example.run_with_retry retry: 2, retry_wait: 1
  end
end
```

---

### 🤔 **5. Docker Compose Integration**

**Question:** Should tests automatically start/stop Docker, or assume it's running?

**Options:**
1. **Assume running:** Developer must start manually
2. **Auto-start:** Tests start Docker if not running
3. **Fail fast:** Tests fail immediately if OpenSearch not available
4. **Both:** Auto-start in CI, assume running locally

**Recommendation:** Option 1 (assume running) + Option 3 (fail fast with helpful message)

**Rationale:**
- Simpler test setup
- Faster test execution (no startup time)
- Developer controls the environment
- Clear error message guides setup

---

### 🤔 **6. Test Parallelization**

**Question:** Should integration tests run in parallel?

**Options:**
1. **Sequential only:** Safer, simpler
2. **Parallel with unique indices:** Faster, more complex
3. **Parallel with separate clusters:** Ideal but complex

**Recommendation:** Option 1 (sequential) initially, Option 2 (parallel) as enhancement

**Considerations:**
- Index naming must be truly unique (include PID)
- Some operations may conflict (cluster settings)
- Cleanup becomes more complex

---

### 🤔 **7. Logging in Tests**

**Question:** How verbose should test logging be?

**Options:**
1. **Silent:** No logging except failures
2. **Minimal:** Only test progress
3. **Detailed:** Show all OpenSearch operations
4. **Configurable:** ENV var controls level

**Recommendation:** Option 4 (configurable)

**Implementation:**
```ruby
def test_logger_level
  ENV.fetch('TEST_LOG_LEVEL', 'WARN').upcase
end

def test_client
  @test_client ||= OpenSearch::Sugar::Client.new(
    logger: Logger.new($stdout, level: test_logger_level)
  )
end
```

---

### 🤔 **8. Performance Benchmarking**

**Question:** Should integration tests include performance benchmarks?

**Options:**
1. **No benchmarks:** Focus on functionality
2. **Basic timing:** Record execution time
3. **Full benchmarks:** Detailed performance tests
4. **Separate suite:** Performance tests separate from integration

**Recommendation:** Option 2 (basic timing) + Option 4 (separate suite later)

**Implementation:**
```ruby
# In spec_helper.rb
RSpec.configure do |config|
  config.around(:each, :timed) do |example|
    start = Time.now
    example.run
    duration = Time.now - start
    example.metadata[:duration] = duration
    
    if duration > example.metadata[:max_duration]
      warn "Test took #{duration}s (max: #{example.metadata[:max_duration]}s)"
    end
  end
end

# In tests:
it "performs bulk indexing quickly", timed: true, max_duration: 5 do
  # ...
end
```

---

## Test Execution Strategy

### Test Order

```ruby
RSpec.configure do |config|
  # Run in defined order for cleanup verification
  config.register_ordering :global do |items|
    # Regular tests first
    regular = items.reject { |i| i.metadata[:cleanup_verification] }
    # Cleanup verification last
    verification = items.select { |i| i.metadata[:cleanup_verification] }
    
    regular + verification
  end
end
```

### Test Tags

```ruby
# Run specific subsets:
bundle exec rspec --tag client              # Client tests only
bundle exec rspec --tag index               # Index tests only
bundle exec rspec --tag models              # ML model tests only
bundle exec rspec --tag ~slow               # Skip slow tests
bundle exec rspec --tag ~requires_ml_model  # Skip ML tests
bundle exec rspec --tag vcr                 # Only VCR tests
```

---

## Success Criteria

The integration test suite is complete when:

1. ✅ **Coverage:** All public methods have integration tests
2. ✅ **Real testing:** Tests run against real OpenSearch (not mocked)
3. ✅ **Cleanup:** No test artifacts remain after execution
4. ✅ **Fast enough:** Full suite runs in < 5 minutes
5. ✅ **Reliable:** < 1% flaky test rate
6. ✅ **Documented:** Clear README for running tests
7. ✅ **CI ready:** Works in GitHub Actions
8. ✅ **VCR balance:** Only deterministic operations use VCR
9. ✅ **Error coverage:** Both success and failure paths tested
10. ✅ **Isolated:** Tests don't depend on each other

---

## Estimated Test Count

| Category | Estimated Tests |
|----------|----------------|
| Client | ~25 tests |
| Index | ~40 tests |
| Document Operations | ~20 tests |
| ML Models | ~25 tests |
| Analyzers | ~15 tests |
| Error Handling | ~20 tests |
| **Total** | **~145 tests** |

---

## Next Steps

1. **Create basic infrastructure:**
   - spec_helper.rb
   - Support files
   - Cleanup helpers

2. **Implement first test file:**
   - Start with client_spec.rb (simplest)
   - Validate infrastructure works

3. **Add VCR configuration:**
   - Configure matchers
   - Test with one VCR example

4. **Expand coverage:**
   - Add index_spec.rb
   - Add document_operations_spec.rb
   - Add models_spec.rb (with skip guards)

5. **Refinement:**
   - Add shared examples
   - Optimize cleanup
   - Add performance timing

6. **Documentation:**
   - README for running tests
   - Contributing guide
   - Troubleshooting guide

---

## Appendix: Example Test Structure

```ruby
# Example: spec/integration/index_spec.rb (excerpt)

require 'spec_helper'

RSpec.describe OpenSearch::Sugar::Index, :integration do
  let(:client) { test_client }
  let(:index_name) { generate_test_index_name }
  
  after do
    delete_test_index(index_name) if client.index_exists?(index_name)
  end
  
  describe '.create' do
    it 'creates an index successfully' do
      index = described_class.create(client: client, name: index_name)
      
      expect(index).to be_a(described_class)
      expect(index.name).to eq(index_name)
      expect(client.index_exists?(index_name)).to be true
    end
    
    context 'with k-NN enabled' do
      it 'creates index with k-NN settings' do
        index = described_class.create(client: client, name: index_name, knn: true)
        
        settings = index.settings
        expect(settings.dig(index_name, 'settings', 'index', 'knn')).to be_truthy
      end
    end
    
    context 'when index already exists' do
      before { client.create_index(index_name) }
      
      it 'raises ArgumentError' do
        expect {
          described_class.create(client: client, name: index_name)
        }.to raise_error(ArgumentError, /already exists/)
      end
    end
  end
  
  describe '#update_settings' do
    let(:index) { client.create_index(index_name) }
    
    let(:settings) do
      {
        settings: {
          analysis: {
            analyzer: {
              test_analyzer: {
                type: 'standard',
                stopwords: '_english_'
              }
            }
          }
        }
      }
    end
    
    it 'updates settings successfully' do
      result = index.update_settings(settings)
      
      expect(result[:status]).to eq(:success)
      expect(result[:message]).to include('Updated settings')
      
      # Verify settings were applied
      updated_settings = index.settings
      analyzer = updated_settings.dig(
        index_name, 'settings', 'index', 'analysis', 'analyzer', 'test_analyzer'
      )
      expect(analyzer).to be_present
      expect(analyzer['type']).to eq('standard')
    end
  end
end
```

---

## Implementation Time Estimates

### Human Developer Implementation: 35-50 hours

**Priority Order:**
1. Infrastructure setup (8 hours) - Simpler without VCR
2. Client + Index tests (15 hours)
3. Document operations tests (8 hours)
4. Analyzer tests (5 hours)
5. ML Model tests (10 hours)
6. Error handling + edge cases (6 hours)
7. Documentation + refinement (3 hours)

**Note:** Time reduced by ~10 hours due to removing VCR complexity. Tests will be simpler, more maintainable, and truly test integration with OpenSearch.

### AI-Assisted Implementation: 4-8 hours

With AI assistance (e.g., GitHub Copilot, GPT-4), implementation time can be significantly reduced:

**Phase 1: Infrastructure (1-2 hours)**
- AI generates spec_helper.rb and support files
- Human reviews and adjusts for project specifics
- Set up Docker integration and wait scripts

**Phase 2: Core Test Implementation (2-4 hours)**
- AI generates test file scaffolding
- AI writes test cases based on method signatures
- Human reviews, runs tests, fixes issues iteratively
- Human validates against real OpenSearch behavior

**Phase 3: Refinement (1-2 hours)**
- Add shared examples and contexts
- Optimize cleanup strategies
- Fix any flaky tests
- Add documentation

**Advantages of AI-Assisted Approach:**
- Rapid scaffolding generation
- Consistent test patterns
- Comprehensive coverage suggestions
- Quick iteration on feedback

**Human Still Required For:**
- Understanding domain-specific edge cases
- Validating test behavior against real OpenSearch
- Debugging infrastructure issues
- Making architectural decisions
- Ensuring tests are meaningful, not just passing

