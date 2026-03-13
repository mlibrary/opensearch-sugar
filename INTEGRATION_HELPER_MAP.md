# Integration Helper Integration Map

## How `integration_helper.rb` is integrated into the spec suite

### 1. **Automatic Loading via `spec_helper.rb`**

The integration_helper is automatically loaded through this line in `spec/spec_helper.rb`:

```ruby
# Load support files
Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }
```

This loads **all** `.rb` files in `spec/support/` and its subdirectories, including:
- `spec/support/integration_helper.rb`
- `spec/support/retry_config.rb`

### 2. **Integration via RSpec Metadata**

The `IntegrationHelper` module is automatically included in tests tagged with `type: :integration`:

**In `integration_helper.rb` (bottom of file):**
```ruby
RSpec.configure do |config|
  config.include IntegrationHelper, type: :integration
  # ... hooks ...
end
```

### 3. **Usage in Test Files**

Test files use the helper by:

**a) Adding the `type: :integration` metadata:**
```ruby
# In spec/integration/client_spec.rb
RSpec.describe OpenSearch::Sugar::Client, type: :integration do
  # ...
end

# In spec/integration/index_spec.rb
RSpec.describe OpenSearch::Sugar::Index, type: :integration do
  # ...
end
```

**b) Using helper methods directly (no explicit include needed):**
```ruby
it "performs bulk indexing" do
  docs = generate_documents(10)          # ← Helper method
  index = create_test_index              # ← Helper method
  wait_for_documents(index)              # ← Helper method
  expect(test_client.ping).to be true    # ← Helper method
end
```

### 4. **Integration Flow Diagram**

```
┌─────────────────────────────────────────────────────────────┐
│ Test Execution Start                                         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ spec/spec_helper.rb loads                                    │
│   require "opensearch/sugar"                                 │
│   require "timecop"                                          │
│   Dir[support/**/*.rb].each { |f| require f }  ← LOADS ALL  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ├──────────────────────┬─────────────────┐
                     ▼                      ▼                 ▼
        ┌─────────────────────┐  ┌──────────────────┐  ┌──────────┐
        │ integration_helper  │  │ retry_config.rb  │  │ others   │
        │ .rb loads           │  │ loads            │  │ (future) │
        └──────────┬──────────┘  └────────┬─────────┘  └──────────┘
                   │                      │
                   │                      │
                   ▼                      ▼
        ┌──────────────────────────────────────────────┐
        │ RSpec.configure do |config|                  │
        │   config.include IntegrationHelper,          │
        │                  type: :integration          │
        │ end                                          │
        └──────────────────────────────────────────────┘
                             │
                             ▼
        ┌──────────────────────────────────────────────┐
        │ Integration tests run with metadata:         │
        │   RSpec.describe X, type: :integration       │
        └──────────┬───────────────────────────────────┘
                   │
                   ▼
        ┌──────────────────────────────────────────────┐
        │ Helper methods available automatically:       │
        │   • test_client                              │
        │   • test_index_name                          │
        │   • create_test_index                        │
        │   • generate_document(s)                     │
        │   • wait_for_index                           │
        │   • wait_for_documents                       │
        │   • cleanup_test_indices                     │
        │   • book_mapping                             │
        │   • standard_settings                        │
        │   • opensearch_available?                    │
        │   • cluster_health                           │
        │   • retry_on_failure                         │
        └──────────────────────────────────────────────┘
```

### 5. **Automatic Hooks**

The integration helper also registers RSpec hooks that run automatically:

**After each integration test:**
```ruby
config.after(:each, type: :integration) do
  cleanup_test_indices  # Automatically cleans up test indices
end
```

**After entire test suite:**
```ruby
config.after(:suite) do
  next unless ENV["RUN_INTEGRATION_TESTS"]
  # Cleanup any remaining test indices
end
```

### 5.5 **Constant Handling**

Module constants are NOT automatically available when a module is included. The `IntegrationHelper` module uses a `before(:context)` hook in RSpec to copy constants into each example group:

```ruby
module IntegrationHelper
  # Constants remain in module namespace
  OPENSEARCH_URL = ENV.fetch("OPENSEARCH_URL", "http://localhost:9200")
  OPENSEARCH_USER = ENV.fetch("OPENSEARCH_USER", "admin")
  OPENSEARCH_PASSWORD = ENV.fetch("OPENSEARCH_PASSWORD", "admin")
  TEST_INDEX_PREFIX = "test_opensearch_sugar"
  
  # Helper methods reference module constants explicitly
  def test_client
    @test_client ||= OpenSearch::Sugar::Client.new(
      url: IntegrationHelper::OPENSEARCH_URL,
      user: IntegrationHelper::OPENSEARCH_USER,
      password: IntegrationHelper::OPENSEARCH_PASSWORD,
      log: false
    )
  end
end

# RSpec configuration
RSpec.configure do |config|
  config.include IntegrationHelper, type: :integration
  
  # Copy constants to example group class before tests run
  config.before(:context, type: :integration) do
    self.class.const_set(:OPENSEARCH_URL, IntegrationHelper::OPENSEARCH_URL) unless self.class.const_defined?(:OPENSEARCH_URL)
    self.class.const_set(:OPENSEARCH_USER, IntegrationHelper::OPENSEARCH_USER) unless self.class.const_defined?(:OPENSEARCH_USER)
    self.class.const_set(:OPENSEARCH_PASSWORD, IntegrationHelper::OPENSEARCH_PASSWORD) unless self.class.const_defined?(:OPENSEARCH_PASSWORD)
    self.class.const_set(:TEST_INDEX_PREFIX, IntegrationHelper::TEST_INDEX_PREFIX) unless self.class.const_defined?(:TEST_INDEX_PREFIX)
  end
end
```

This allows tests to use `OPENSEARCH_URL` directly instead of `IntegrationHelper::OPENSEARCH_URL`.

**Why `before(:context)` instead of `self.included`?**
- RSpec's inclusion mechanism works differently than simple class inclusion
- `before(:context)` runs at the example group level where constants need to be defined
- This approach works reliably with RSpec's test execution model

### 6. **Key Points**

1. **No explicit require needed** - `spec_helper.rb` auto-loads all support files
2. **Automatic inclusion** - Adding `type: :integration` includes the helper
3. **All methods available** - Helper methods work like they're part of the test
4. **Automatic cleanup** - Hooks run automatically without manual calls
5. **Environment-aware** - Only runs when `RUN_INTEGRATION_TESTS=true`

### 7. **Example Usage in Tests**

```ruby
# spec/integration/client_spec.rb
require "spec_helper"  # ← Loads everything

RSpec.describe OpenSearch::Sugar::Client, type: :integration do
  #                                        ↑
  #                            This metadata triggers inclusion
  
  it "performs search" do
    # All these methods come from IntegrationHelper:
    index = create_test_index(mappings: book_mapping)
    docs = generate_documents(10)
    docs.each { |doc| index.index(id: doc[:id], body: doc) }
    wait_for_documents(index, expected_count: 10)
    
    results = test_client.search(...)
    expect(results).to ...
  end
  
  # After this test runs, cleanup_test_indices is called automatically
end
```

### 8. **File Locations**

```
spec/
├── spec_helper.rb              ← Auto-loads support files
├── support/
│   ├── integration_helper.rb   ← Loaded automatically
│   └── retry_config.rb         ← Loaded automatically
└── integration/
    ├── client_spec.rb          ← Uses type: :integration
    └── index_spec.rb           ← Uses type: :integration
```

### 9. **Summary**

The integration is **completely automatic**:

1. Run any spec file → `spec_helper.rb` loads
2. `spec_helper.rb` loads all `support/*.rb` files
3. `integration_helper.rb` registers itself with RSpec for `:integration` type
4. Any test with `type: :integration` gets all helper methods
5. Cleanup hooks run automatically after each test and after the suite

**No manual requires or includes needed in test files!**

