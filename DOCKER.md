# Docker Integration Testing Setup

This directory contains Docker configurations optimized for running integration tests with OpenSearch and Ruby.

## Quick Start

```bash
# 1. Copy environment file
cp .env.example .env

# 2. Run tests
./run-tests.sh

# 3. Start development shell (optional)
./dev-shell.sh
```

## Architecture

- **opensearch** - OpenSearch 2.18.0 with analysis-icu plugin
- **test** - Ruby 3.4 container with test dependencies

## Files

- `Dockerfile` - Multi-stage Ruby build optimized for testing
- `Dockerfile.opensearch` - OpenSearch with plugins and health checks
- `compose.yml` - Docker Compose orchestration
- `run-tests.sh` - Automated test runner script
- `dev-shell.sh` - Interactive development shell
- `.dockerignore` - Excluded files for faster builds
- `.env.example` - Environment variable template

## Usage

### Running Tests

```bash
# Basic test run
./run-tests.sh

# Rebuild containers before testing
./run-tests.sh --rebuild

# Clean up volumes after tests
./run-tests.sh --cleanup

# Show container logs
./run-tests.sh --logs
```

### Manual Docker Compose Commands

```bash
# Start OpenSearch only
docker compose up -d opensearch

# Run tests
docker compose run --rm test

# Run specific test file
docker compose run --rm test bundle exec rspec spec/my_spec.rb

# Start interactive shell
docker compose run --rm test /bin/bash

# View logs
docker compose logs -f opensearch

# Stop all services
docker compose down

# Clean up everything (including volumes)
docker compose down -v
```

### Development Workflow

```bash
# Start development environment
./dev-shell.sh

# Inside the container:
bundle exec rspec                    # Run all tests
bundle exec rspec spec/my_spec.rb    # Run specific test
bundle exec irb                      # Interactive Ruby
bundle exec rake                     # Run rake tasks
```

## Configuration

### Environment Variables

Edit `.env` file or set environment variables:

```bash
# OpenSearch credentials
OPENSEARCH_INITIAL_ADMIN_PASSWORD=TestPassword123!
OPENSEARCH_URL=http://opensearch:9200
OPENSEARCH_USER=admin

# User/Group IDs (match your local user)
UID=1000
GID=1000

# CI flag
CI=false
```

### Performance Tuning

#### For Local Development
The default configuration uses minimal resources:
- OpenSearch heap: 512MB (Xms512m/Xmx512m)
- Security disabled for faster startup
- Single node cluster

#### For CI/CD
Set `CI=true` to enable CI-specific optimizations.

## Optimizations

### Build Optimizations
1. **Multi-stage builds** reduce final image size
2. **Layer caching** - dependencies installed before code copy
3. **.dockerignore** excludes unnecessary files
4. **Minimal base images** (ruby:3.4-slim)

### Runtime Optimizations
1. **Health checks** ensure services are ready
2. **Service dependencies** prevent race conditions
3. **Reduced memory** footprint for testing
4. **Security disabled** for faster OpenSearch startup
5. **Volume caching** for gems and data

### Network Optimizations
1. **Dedicated bridge network** for service isolation
2. **Service DNS** - use `opensearch` hostname
3. **Only necessary ports** exposed

## Troubleshooting

### OpenSearch won't start

```bash
# Check logs
docker compose logs opensearch

# Increase memory if needed (edit compose.yml)
# OPENSEARCH_JAVA_OPTS=-Xms1G -Xmx1G

# Verify ulimits
docker compose exec opensearch ulimit -a
```

### Tests can't connect to OpenSearch

```bash
# Verify OpenSearch is healthy
docker compose ps

# Check network connectivity
docker compose exec test ping opensearch

# Verify environment variables
docker compose exec test env | grep OPENSEARCH
```

### Permission issues

```bash
# Set your UID/GID in .env
echo "UID=$(id -u)" >> .env
echo "GID=$(id -g)" >> .env

# Rebuild
docker compose build --no-cache
```

### Slow builds

```bash
# Use BuildKit for faster builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# Clean build cache if needed
docker builder prune
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      
      - name: Run tests
        run: |
          cp .env.example .env
          ./run-tests.sh --cleanup
        env:
          CI: true
```

### GitLab CI Example

```yaml
test:
  image: docker:latest
  services:
    - docker:dind
  script:
    - cp .env.example .env
    - ./run-tests.sh --cleanup
  variables:
    CI: "true"
```

## Performance Benchmarks

Typical startup times on modern hardware:
- OpenSearch ready: ~30-45 seconds
- Ruby container build (cached): ~5-10 seconds
- Test suite execution: depends on your tests

## Security Notes

⚠️ **These configurations are for TESTING ONLY!**

- Security plugin is disabled
- Default passwords are used
- No SSL/TLS encryption
- NOT suitable for production use

## Version Compatibility

- Docker: 20.10+
- Docker Compose: 2.0+
- OpenSearch: 2.18.0
- Ruby: 3.4

## Contributing

When modifying Docker configurations:
1. Test with `--rebuild` flag
2. Verify health checks work
3. Document any new environment variables
4. Update this README

## Support

For issues:
1. Check logs: `docker compose logs`
2. Verify health: `docker compose ps`
3. Clean rebuild: `docker compose down -v && ./run-tests.sh --rebuild`

