# OpenSearch::Sugar API Changes

This document describes the API changes between the `main` branch and the current version (vibe2).

**Date:** April 28, 2026

---

## Summary

The current version introduces several **breaking changes** focused on improving:
- Security (SSL verification enabled by default)
- Error handling (explicit exceptions instead of result hashes)
- Observability (structured logging)
- Model management (timeout controls, explicit search methods)

---

## Breaking Changes

### 1. Client: SSL Verification Now Enabled by Default

**Main Branch:**
```ruby
def default_args
  {
    # ...
    transport_options: {ssl: {verify: false}}
  }
end
```

**Current Version:**
```ruby
def default_args
  {
    # ...
    transport_options: {ssl: {verify: true}}
  }
end
```

**Migration Guide:**
- For production: SSL verification should remain enabled (no action needed)
- For development with self-signed certificates, explicitly disable:
  ```ruby
  client = OpenSearch::Sugar.new(
    transport_options: {ssl: {verify: false}}
  )
  ```

---

### 2. Client: Error Handling Changed from Result Hashes to Exceptions

#### `update_settings` Method

**Main Branch:**
```ruby
def update_settings(settings, index_name)
  # ... perform update ...
  {
    status: "success",
    message: "Updated settings for index #{index_name}",
    metadata: settings[:metadata]
  }
rescue => e
  {
    status: "error",
    message: "Failed to update settings: #{e.message}",
    backtrace: e.backtrace
  }
end
```

**Current Version:**
```ruby
def update_settings(settings, index_name)
  # ... perform update ...
  # Returns nothing on success
rescue OpenSearch::Transport::Transport::Error
  reopen_index(index_name)
  raise  # Re-raises the exception
end
```

**Migration Guide:**

Old code:
```ruby
result = client.update_settings(settings, "my_index")
if result[:status] == "success"
  puts "Settings updated: #{result[:message]}"
else
  puts "Error: #{result[:message]}"
end
```

New code:
```ruby
begin
  client.update_settings(settings, "my_index")
  puts "Settings updated successfully"
rescue OpenSearch::Transport::Transport::Error => e
  puts "Error: #{e.message}"
end
```

#### `update_mappings` Method

Same change applies to `update_mappings` - it now raises exceptions instead of returning result hashes.

---

### 3. Models: Exception Hierarchy Added

**Main Branch:** Generic string errors
```ruby
raise model_install_response["error"].to_s  # Line 25
raise "Can't find model #{model}"           # Line 78
# No error handling in undeploy! or delete!
```

**Current Version:** Structured exception classes
```ruby
class ModelError < OpenSearch::Sugar::Error; end
class ModelDeploymentError < ModelError; end
class ModelNotFoundError < ModelError; end
class TimeoutError < ModelError; end
```

**Migration Guide:**

Old code:
```ruby
begin
  client.models.register(name: "my-model", version: "1.0")
rescue => e
  # Catches generic errors
end
```

New code:
```ruby
begin
  client.models.register(
    name: "my-model", 
    version: "1.0",
    timeout: 300,
    poll_interval: 5
  )
rescue OpenSearch::Sugar::Models::TimeoutError => e
  puts "Model deployment timed out: #{e.message}"
rescue OpenSearch::Sugar::Models::ModelDeploymentError => e
  puts "Model deployment failed: #{e.message}"
rescue OpenSearch::Sugar::Models::ModelError => e
  puts "Model error: #{e.message}"
end
```

---

## New Features

### 1. Client: Logger Support

**Current Version:**
```ruby
attr_reader :raw_client, :models, :logger

def initialize(host: ENV["OPENSEARCH_URL"] || ENV["OPENSEARCH_HOST"] || "https://localhost:9000", 
               logger: nil, **kwargs)
  @logger = logger || Logger.new($stdout, level: Logger::WARN)
  # ...
end
```

**Usage:**
```ruby
# Use default logger
client = OpenSearch::Sugar.new

# Use custom logger
custom_logger = Logger.new('app.log', level: Logger::INFO)
client = OpenSearch::Sugar.new(logger: custom_logger)

# Access logger
client.logger.info "Performing operation..."
```

---

### 2. Models: Timeout and Polling Controls

**Main Branch:**
```ruby
def register(name:, version:, format: "TORCH_SCRIPT")
  # Fixed 5-second poll interval, no timeout
  while true
    model_install_response = @os.http.get("_plugins/_ml/tasks/#{taskid}")
    pp model_install_response  # Debug output to console
    break if model_install_response["state"] == "COMPLETED"
    raise model_install_response["error"].to_s if model_install_response["state"] == "FAILED"
    sleep(5)
  end
end
```

**Current Version:**
```ruby
DEFAULT_DEPLOYMENT_TIMEOUT = 300    # 5 minutes
DEFAULT_POLL_INTERVAL = 5           # 5 seconds

def register(name:, version:, format: "TORCH_SCRIPT", 
             timeout: DEFAULT_DEPLOYMENT_TIMEOUT,
             poll_interval: DEFAULT_POLL_INTERVAL)
  # Configurable timeout and polling
  # Structured logging instead of pp
  wait_for_deployment(taskid, timeout: timeout, poll_interval: poll_interval)
end

private

def wait_for_deployment(task_id, timeout:, poll_interval:)
  deadline = Time.now + timeout
  loop do
    raise TimeoutError, "Model deployment timed out after #{timeout} seconds" if Time.now >= deadline
    model_install_response = @os.http.get("_plugins/_ml/tasks/#{task_id}")
    @logger.debug "Model installation status: #{model_install_response}"
    # ... state checking ...
  end
end
```

**Usage:**
```ruby
# Use defaults (5 minutes timeout, 5 seconds poll)
model = client.models.register(name: "my-model", version: "1.0")

# Custom timeout and polling
model = client.models.register(
  name: "large-model",
  version: "2.0",
  timeout: 600,        # 10 minutes
  poll_interval: 10    # Check every 10 seconds
)
```

---

### 3. Models: Explicit Search Methods

**Main Branch:** Only the ambiguous `[]` method

**Current Version:** Explicit methods with clear semantics

```ruby
# Find by exact name
model = client.models.find_by_name('huggingface/sentence-transformers/all-MiniLM-L12-v2')

# Find by exact ID
model = client.models.find_by_id('abc123xyz')

# Search with pattern (case-insensitive, returns array sorted by version)
models = client.models.search('minilm')
models.each { |m| puts "#{m.name} v#{m.version}" }
```

The `[]` method still works but is deprecated:
```ruby
# Still works, tries name -> id -> pattern matching
model = client.models['minilm']
# But prefer explicit methods for clarity
```

---

### 4. Models: Enhanced Error Handling for Lifecycle Operations

**Current Version:**
```ruby
def undeploy!(name_or_id)
  model = find_by_id(name_or_id) || find_by_name(name_or_id)
  raise ModelNotFoundError, "Model '#{name_or_id}' not found" unless model
  @os.http.post("/_plugins/_ml/models/#{model.id}/_undeploy")
end

def delete!(name_or_id)
  model = find_by_id(name_or_id) || find_by_name(name_or_id)
  raise ModelNotFoundError, "Model '#{name_or_id}' not found" unless model
  undeploy!(model.id)
  @os.http.delete("/_plugins/_ml/models/#{model.id}")
end

def create_pipeline(name:, model:, description:, field_map:)
  m = self[model]
  raise ModelNotFoundError, "Can't find model '#{model}'" unless m
  # ...
end
```

**Main Branch:** No validation, would raise generic errors or nil errors

**Usage:**
```ruby
begin
  client.models.undeploy!('nonexistent-model')
rescue OpenSearch::Sugar::Models::ModelNotFoundError => e
  puts "Model not found: #{e.message}"
end
```

---

## Non-Breaking Changes

### 1. Improved Logging

**Main Branch:** Uses `puts` for error messages
```ruby
def reopen_index(index_name)
  # ...
rescue => open_error
  puts "Warning: Failed to reopen index #{index_name}: #{open_error.message}"
end
```

**Current Version:** Uses structured logger
```ruby
def reopen_index(index_name)
  # ...
rescue OpenSearch::Transport::Transport::Error => open_error
  logger.warn "Failed to reopen index #{index_name}: #{open_error.message}"
end
```

---

### 2. Code Quality Improvements

- More specific exception handling (catching specific exception types instead of bare `rescue`)
- Debug logging for deployment status instead of `pp` side effects
- Better method organization (private `wait_for_deployment` method)
- More descriptive error messages

---

## Index Class

**No changes** - The Index class API remains fully compatible.

---

## Migration Checklist

- [ ] Review SSL configuration - enable for production, explicitly disable for dev if needed
- [ ] Update error handling for `update_settings` from hash checking to exception handling
- [ ] Update error handling for `update_mappings` from hash checking to exception handling
- [ ] Update model error handling to catch specific exception types
- [ ] Consider adding custom logger to client initialization
- [ ] Consider using explicit model search methods (`find_by_name`, `find_by_id`, `search`) instead of `[]`
- [ ] Review model deployment code to add custom timeouts if needed
- [ ] Test that exception handling works correctly in your application

---

## Compatibility Notes

### What Remains Compatible

- All `Index` class methods
- Basic `Client` instantiation (if SSL verification was not relied upon being off)
- Model `list` and `raw_list` methods
- Model `deploy` alias for `register`
- Pipeline creation (except error types)

### What Requires Changes

- Code that checks `result[:status]` from `update_settings` or `update_mappings`
- Code that explicitly relies on SSL verification being disabled
- Code that catches generic exceptions from model operations
- Code that relies on `pp` output during model deployment

---

## Recommendations

1. **Enable SSL in Development:** Instead of relying on disabled SSL, set up proper certificates or use mkcert for local development

2. **Use Structured Exception Handling:** Take advantage of the new exception hierarchy to handle different error conditions appropriately

3. **Add Logging:** Pass a custom logger to see detailed operation logs during debugging

4. **Set Appropriate Timeouts:** For large models, increase the timeout parameter to avoid premature failures

5. **Use Explicit Search Methods:** Replace ambiguous `models[query]` with explicit `find_by_name`, `find_by_id`, or `search`

---

## Questions or Issues?

If you encounter issues during migration or have questions about the new API, please consult the full documentation in the `docs/` directory.

