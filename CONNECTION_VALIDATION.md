# Connection Parameter Validation - Implementation Summary

## Changes Made

### File: `lib/opensearch/sugar/client.rb`

Added validation to ensure that `host`, `user`, and `password` are all set when creating a new `OpenSearch::Sugar::Client` instance.

## Implementation Details

### 1. Updated `build_connection_args` Method

The method now validates that all required connection parameters are present after merging user-provided values with defaults:

```ruby
def build_connection_args(host:, user:, password:, timeout:, retries:, **kwargs)
  # Start with defaults
  args = default_args.merge(kwargs)
  
  # Override with explicitly provided values
  args[:host] = host if host
  args[:user] = user if user
  args[:password] = password if password
  args[:request_timeout] = timeout
  args[:retry_on_failure] = retries
  
  # Validate that we have all required connection parameters
  validate_connection_args!(args)
  
  args
end
```

### 2. Added `validate_connection_args!` Method

New private method that validates required connection parameters:

```ruby
def validate_connection_args!(args)
  missing = []
  
  if args[:host].nil? || args[:host].to_s.strip.empty?
    missing << "host (provide via 'host:' parameter or OPENSEARCH_URL/OPENSEARCH_HOST env var)"
  end
  
  if args[:user].nil? || args[:user].to_s.strip.empty?
    missing << "user (provide via 'user:' parameter or OPENSEARCH_USER env var)"
  end
  
  if args[:password].nil? || args[:password].to_s.strip.empty?
    missing << "password (provide via 'password:' parameter or OPENSEARCH_PASSWORD/OPENSEARCH_INITIAL_ADMIN_PASSWORD env var)"
  end
  
  unless missing.empty?
    raise ArgumentError, "Missing required connection parameter(s): #{missing.join("; ")}."
  end
end
```

## Behavior

### Valid Scenarios (No Error)

1. **All parameters provided explicitly:**
   ```ruby
   client = OpenSearch::Sugar::Client.new(
     host: "http://localhost:9200",
     user: "admin",
     password: "secret123"
   )
   ```

2. **Parameters from environment variables:**
   ```bash
   export OPENSEARCH_URL="http://localhost:9200"
   export OPENSEARCH_USER="admin"
   export OPENSEARCH_PASSWORD="secret123"
   ```
   ```ruby
   client = OpenSearch::Sugar::Client.new
   ```

3. **Mix of explicit and environment:**
   ```ruby
   # OPENSEARCH_USER and OPENSEARCH_PASSWORD set in env
   client = OpenSearch::Sugar::Client.new(host: "http://localhost:9200")
   ```

### Invalid Scenarios (Raises ArgumentError)

1. **Missing all parameters:**
   ```ruby
   client = OpenSearch::Sugar::Client.new  # No env vars set
   # => ArgumentError: Missing required connection parameter(s): 
   #    host (provide via 'host:' parameter or OPENSEARCH_URL/OPENSEARCH_HOST env var); 
   #    user (provide via 'user:' parameter or OPENSEARCH_USER env var); 
   #    password (provide via 'password:' parameter or OPENSEARCH_PASSWORD/OPENSEARCH_INITIAL_ADMIN_PASSWORD env var).
   ```

2. **Missing password:**
   ```ruby
   client = OpenSearch::Sugar::Client.new(
     host: "http://localhost:9200",
     user: "admin"
   )
   # => ArgumentError: Missing required connection parameter(s): 
   #    password (provide via 'password:' parameter or OPENSEARCH_PASSWORD/OPENSEARCH_INITIAL_ADMIN_PASSWORD env var).
   ```

3. **Empty string values:**
   ```ruby
   client = OpenSearch::Sugar::Client.new(
     host: "  ",
     user: "",
     password: ""
   )
   # => ArgumentError: Missing required connection parameter(s): host...; user...; password...
   ```

## Error Messages

The error messages are helpful and specific:
- Clearly state which parameters are missing
- Provide guidance on how to supply them (via parameter or environment variable)
- List all applicable environment variable names for each parameter

## Backward Compatibility

This change adds validation but maintains backward compatibility:
- Existing code that provides all required parameters continues to work
- Existing code that relies on environment variables continues to work  
- Only code that was previously creating clients with missing credentials will now fail with a clear error message (which is the desired behavior)

## Testing

The implementation has been verified to:
- ✓ Reject clients when parameters are missing
- ✓ Reject clients when parameters are empty strings
- ✓ Accept clients when all parameters are provided explicitly
- ✓ Accept clients when parameters come from environment variables
- ✓ Provide clear, actionable error messages

## Integration Tests

The existing integration test suite in `spec/integration/` already provides default values via environment variables in `spec/support/integration_helper.rb`, so all integration tests continue to work correctly.

