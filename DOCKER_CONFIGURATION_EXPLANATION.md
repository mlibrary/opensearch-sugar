# Docker Configuration Explanation

## Summary

~~There are **two separate Docker configurations** in this repository:~~

**UPDATE (2024):** The legacy `spec/docker/` configuration has been **removed**. 

This repository now has a **single Docker configuration** at the repository root:

**Top-level configuration** (`/compose.yml`, `/Dockerfile`, `/Dockerfile.opensearch`)

This document is preserved for historical reference to explain why the duplicate configuration existed and why it was removed.

---

## Current Docker Configuration (Active)

**Location:** Repository root
- `compose.yml`
- `Dockerfile` (multi-stage build)
- `Dockerfile.opensearch`
- `.env.example`
- `run-tests.sh`
- `dev-shell.sh`

**Purpose:** **Optimized for running integration tests**

**Characteristics:**
- **Modern multi-stage build** - Uses build stages (`base`, `dependencies`, `test`)
- **Integration test focused** - Specifically designed for `spec/integration/` tests
- **Two services:**
  - `opensearch` - OpenSearch 2.x with security disabled for testing
  - `test` - Ruby 3.4 container with all test dependencies
- **Health checks** - Ensures OpenSearch is ready before running tests
- **Automated scripts:**
  - `run-tests.sh` - Automated test runner
  - `run-integration-tests.sh` - Integration test specific runner
- **Optimizations:**
  - Smaller memory footprint (512MB for OpenSearch)
  - Fast startup (security disabled)
  - Volume caching for gems
  - Single-node cluster for speed

**Usage:**
```bash
# Run integration tests
./run-integration-tests.sh

# Or manually
docker-compose up -d
RUN_INTEGRATION_TESTS=true bundle exec rake integration
```

**Status:** ✅ **ACTIVE** - This is the current, recommended configuration

---

## Historical Context: Removed Spec-Level Configuration

**Former Location:** `/spec/docker/` (**REMOVED**)

The following information is preserved for historical reference:

### What Was Removed

- `spec/docker/compose.yml` (included `compose_opensearch.yml`)
- `spec/docker/compose_opensearch.yml`
- `spec/docker/Dockerfile`
- `spec/docker/Dockerfile.opensearch`
- `spec/docker/.env`
- `spec/docker/env.development`

### Why It Existed

**Purpose:** **Original development environment setup**

**Characteristics:**
- **Simpler, older structure** - Basic Dockerfile without multi-stage build
- **Development focused** - Used for general development work
- **Service composition:**
  - `dor-opensearch` - OpenSearch with standard configuration
  - `app` - Ruby development container
- **Platform specific** - Hardcoded `platform: linux/aarch64` (ARM)
- **Keeps container running** - `command: "tail -f /dev/null"` for interactive work
- **No health checks** - Manual verification required
- **OpenSearch security enabled** - Closer to production configuration

### Why It Was Removed

1. **Outdated** - Not maintained alongside the top-level configuration
2. **Redundant** - Top-level configuration provides all necessary functionality
3. **Confusing** - Having two configurations caused confusion for developers
4. **Unused** - Not referenced by current test infrastructure or documentation
5. **Inferior** - Top-level configuration has better features (health checks, multi-stage build, automation)

---

## Historical Comparison (For Reference)

| Aspect | Top-Level (Kept) | Spec (Removed) |
|--------|------------------|----------------|
| **Purpose** | Integration testing | Development environment |
| **Build** | Multi-stage, optimized | Simple, basic |
| **OpenSearch** | Security disabled, fast startup | Security enabled, standard |
| **Memory** | 512MB (minimal) | Default (larger) |
| **Ruby version** | 3.4-slim | Ubuntu-based |
| **Health checks** | ✅ Yes | ❌ No |
| **Automation** | Scripts included | Manual |
| **Network** | `test-network` | `opensearch-net` |
| **Container names** | `opensearch-test`, `ruby-test` | `opensearch`, `app` |
| **Platform** | Multi-platform | ARM-specific |
| **Dependencies** | Managed via stages | Installed directly |
| **Use case** | Run tests in CI/local | Development shell |

---

## Historical Development Timeline

1. **Phase 1: Original Development** (`spec/docker/`)
   - Created initially for development work
   - Basic Docker setup
   - Used for manual testing and exploration
   - Kept security enabled for realistic environment

2. **Phase 2: Integration Test Suite** (top-level)
   - Created specifically for automated integration tests
   - Optimized for CI/CD pipelines
   - Security disabled for speed
   - Health checks for reliability
   - Automated via scripts

3. **Phase 3: Cleanup** (2024)
   - **Removed `spec/docker/` configuration**
   - Single source of truth for Docker configuration
   - Cleaner, less confusing repository structure

---

## Current Best Practice

**Use the top-level Docker configuration:**

```bash
# For integration tests
./run-integration-tests.sh

# For development shell
./dev-shell.sh

# For manual control
docker-compose up -d
docker-compose run test /bin/bash
```

---

## Conclusion

The repository **previously had two Docker configurations** because:
1. **Top-level** - Modern, optimized for integration testing
2. **spec/docker** - Legacy development environment

**Resolution (2024):** The legacy `spec/docker/` configuration was **removed** to:
- Eliminate confusion
- Maintain a single source of truth
- Simplify repository structure
- Reduce maintenance burden

The top-level Docker configuration is now the **only** configuration and provides all necessary functionality for both development and integration testing.



