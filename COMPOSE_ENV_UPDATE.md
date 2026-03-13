# Docker Compose Configuration Update - Using spec/env.spec

## Summary

Updated `compose.yml` to use environment variables from `spec/env.spec` for OpenSearch credentials.

## Changes Made

### 1. OpenSearch Service

**Added:**
- `env_file: - spec/env.spec` to load environment variables from the spec file

**Changed:**
- `OPENSEARCH_INITIAL_ADMIN_PASSWORD`: Now uses `${OPENSEARCH_PASSWORD}` from spec/env.spec instead of `${OPENSEARCH_INITIAL_ADMIN_PASSWORD:-TestPassword123!}`

**Environment variables loaded from spec/env.spec:**
- `OPENSEARCH_USER="admin"`
- `OPENSEARCH_PASSWORD="Dw2F%3E*!m&psx64"`
- `OPENSEARCH_URL="http://localhost:9000"` (not used by opensearch service, only by test service)

### 2. Test Service

**Added:**
- `env_file: - spec/env.spec` to load environment variables from the spec file

**Changed:**
- Now loads `OPENSEARCH_USER` and `OPENSEARCH_PASSWORD` from spec/env.spec
- Overrides `OPENSEARCH_URL` to `http://opensearch:9200` (Docker service name)
- Overrides `OPENSEARCH_HOST` to `http://opensearch:9200` (Docker service name)

**Why the override?**
The `spec/env.spec` file has `OPENSEARCH_URL="http://localhost:9000"` which is for external access. Inside Docker Compose, the test container needs to connect to the `opensearch` service using the service name, not `localhost`.

## File: spec/env.spec

```bash
OPENSEARCH_USER="admin"
OPENSEARCH_PASSWORD="Dw2F%3E*!m&psx64"
OPENSEARCH_URL="http://localhost:9000"
```

## Resulting Configuration

### OpenSearch Service
- Uses `OPENSEARCH_PASSWORD` from spec/env.spec for `OPENSEARCH_INITIAL_ADMIN_PASSWORD`
- Accessible on host at `http://localhost:9200`

### Test Service  
- Uses `OPENSEARCH_USER` from spec/env.spec: `admin`
- Uses `OPENSEARCH_PASSWORD` from spec/env.spec: `Dw2F%3E*!m&psx64`
- Overrides `OPENSEARCH_URL` to `http://opensearch:9200` (for Docker networking)
- Overrides `OPENSEARCH_HOST` to `http://opensearch:9200` (for Docker networking)

## Benefits

1. **Single source of truth** - Credentials defined in one place (spec/env.spec)
2. **No hardcoded passwords** - Removed default `TestPassword123!`
3. **Consistent credentials** - Both services use the same user/password
4. **Easy to change** - Update spec/env.spec to change credentials for both services

## Usage

```bash
# Start services with credentials from spec/env.spec
docker-compose up -d

# Run tests (will use credentials from spec/env.spec)
docker-compose run test bundle exec rspec

# Or use the integration test script
./run-integration-tests.sh
```

## Note on Port Difference

The `spec/env.spec` file specifies port 9000:
```bash
OPENSEARCH_URL="http://localhost:9000"
```

But the `compose.yml` exposes OpenSearch on port 9200:
```yaml
ports:
  - "9200:9200"
```

If you want to use port 9000 externally, update the compose.yml:
```yaml
ports:
  - "9000:9200"
```

Or update spec/env.spec to use port 9200:
```bash
OPENSEARCH_URL="http://localhost:9200"
```

