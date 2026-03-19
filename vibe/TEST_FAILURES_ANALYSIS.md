# Test Failures Analysis and Fixes

## Initial Test Run

Ran 45 integration tests, 8 failures were found.

---

## Issue 1: RSpec Matcher Error

**Test:** `OpenSearch::Sugar::Client#initialize can retrieve cluster health`

**Error:**
```
expected "green" to respond to `in?`
```

**Root Cause:**
Used `be_in` matcher which doesn't exist in RSpec. The correct approach is to flip the expectation.

**Fix:**
Changed from:
```ruby
expect(health["status"]).to be_in(%w[green yellow red])
```

To:
```ruby
expect(%w[green yellow red]).to include(health["status"])
```

**File:** `spec/integration/client_spec.rb`

**Status:** ✅ Fixed

---

## Issue 2-6: Analyzer Validation Logic

**Tests:** 
- `Index Analysis #all_available_analyzers returns list of available analyzers`
- `Index Analysis #analyze_text analyzes text with standard analyzer`
- `Index Analysis #analyze_text handles empty text`
- `Index Analysis #analyze_text handles text with only stopwords`
- `Index Analysis #analyze_text_field uses different analyzers for different fields`

**Error:**
```
ArgumentError: Analyzer 'standard' does not exist in index 'test_analyze_standard_1773876942'
```

**Root Cause:**
The `analyze_text` method was checking if the analyzer exists in the index settings:
```ruby
unless settings_response.dig(name, "settings", "index", "analysis", "analyzer", analyzer)
  raise ArgumentError, "Analyzer '#{analyzer}' does not exist in index '#{name}'"
end
```

This logic is flawed because:
1. **Built-in analyzers** (standard, simple, whitespace, keyword, etc.) are always available in OpenSearch but are NOT stored in index settings
2. Only **custom analyzers** defined in index settings appear there
3. The pre-check was rejecting valid built-in analyzers

**Fix:**

1. **Removed the pre-check** and let OpenSearch validate the analyzer:
```ruby
def analyze_text(analyzer:, text:)
  # Analyze the text - OpenSearch will return an error if analyzer doesn't exist
  response = client.indices.analyze(
    index: name,
    body: {
      analyzer:,
      text:
    }
  )
  # ...process tokens...
rescue OpenSearch::Transport::Transport::Errors::BadRequest => e
  raise ArgumentError, "Analyzer '#{analyzer}' does not exist in index '#{name}': #{e.message}"
end
```

2. **Updated documentation** for `all_available_analyzers`:
```ruby
# Get a list of all named analyzers available in this index for use when indexing
# Include those defined at the cluster level as well as those defined for this
# particular index. Note: Built-in analyzers (standard, simple, whitespace, etc.)
# are always available but not listed here - this returns custom analyzers only.
# @return [Array<String>] List of custom analyzer names available for this index
```

3. **Updated test expectations**:
Changed from checking for "standard" to expecting empty array for new indexes:
```ruby
it "returns list of custom analyzers (empty for new index)" do
  index = create_test_index(index_name)
  analyzers = index.all_available_analyzers
  expect(analyzers).to be_an(Array)
  expect(analyzers).to be_empty  # New indexes have no custom analyzers
end
```

**Files:** 
- `lib/opensearch/sugar/index.rb` (analyze_text method)
- `lib/opensearch/sugar/index.rb` (all_available_analyzers documentation)
- `spec/integration/index_analysis_spec.rb` (test expectations)

**Status:** ✅ Fixed

---

## Issue 7-8: KNN Setting Type Mismatch

**Tests:**
- `OpenSearch::Sugar::Index.create supports KNN configuration`
- `OpenSearch::Sugar::Index.create supports disabling KNN`

**Error:**
```
expected true
     got #<String:2384> => "true"
```

**Root Cause:**
OpenSearch stores settings as strings in its JSON responses, not as Ruby booleans. When we query the settings, we get back:
```ruby
{"knn" => "true"}  # Not {"knn" => true}
```

The test was expecting Ruby boolean `true`/`false` but getting string `"true"`/`"false"`.

**Fix:**
Updated test expectations to compare against strings:
```ruby
# Before:
expect(settings.dig(index_name, "settings", "index", "knn")).to be true

# After:
expect(settings.dig(index_name, "settings", "index", "knn")).to eq("true")
```

**File:** `spec/integration/index_spec.rb`

**Status:** ✅ Fixed

---

## Summary

All 8 failures have been fixed:

1. **RSpec matcher fix** (1 test) - Changed `be_in` to `include` with flipped expectation
2. **Analyzer validation fix** (5 tests) - Removed faulty pre-check, let OpenSearch validate
3. **KNN type fix** (2 tests) - Compare against strings instead of booleans

**Final Result:** 45 examples, 0 failures ✅

---

## Lessons Learned

### 1. Don't Pre-Validate Against Local Data
The analyzer checking was trying to be smart by validating before making the request, but it didn't account for built-in analyzers. Let the authoritative source (OpenSearch) validate and catch the errors.

### 2. OpenSearch Returns Strings, Not Booleans
JSON doesn't have a boolean type in the same way as Ruby. OpenSearch settings come back as strings ("true", "false", "1", etc.), not Ruby booleans.

### 3. Test Against Actual Behavior
The original tests assumed "standard" would be in the analyzer list, but that's not how OpenSearch works. The fix clarified the actual behavior and updated documentation accordingly.

### 4. Better Error Messages
The new error handling includes the underlying OpenSearch error message, making debugging easier:
```ruby
raise ArgumentError, "Analyzer '#{analyzer}' does not exist in index '#{name}': #{e.message}"
```

---

## Test Execution Time

- Client tests: 0.41 seconds (11 examples)
- Index tests: 1.38 seconds (18 examples)
- Analysis tests: 1.36 seconds (12 examples)
- Aliases tests: 0.35 seconds (4 examples)
- **Total: ~3.5 seconds** for 45 integration tests

Fast enough for rapid development iterations!

