# Docker Integration Testing - Quick Reference

## 🚀 One-Line Commands

```bash
# Run all tests
./run-tests.sh

# Development shell
./dev-shell.sh

# Clean rebuild and test
./run-tests.sh --rebuild --cleanup
```

## 📝 Common Tasks

### Testing
```bash
# Basic test run
docker compose run --rm test

# Specific test file
docker compose run --rm test bundle exec rspec spec/my_spec.rb

# With debugging
docker compose run --rm test bundle exec rspec --format documentation

# With coverage
docker compose run --rm test bundle exec rspec --format html --out coverage.html
```

### Development
```bash
# Interactive Ruby
docker compose run --rm test bundle exec irb

# Rails console (if applicable)
docker compose run --rm test bundle exec rails console

# Run rake task
docker compose run --rm test bundle exec rake my:task

# Install new gem
docker compose run --rm test bundle install
docker compose build test  # Rebuild to cache
```

### Debugging
```bash
# Shell in test container
docker compose run --rm test /bin/bash

# Shell in running container
docker compose exec test /bin/bash

# View OpenSearch logs
docker compose logs -f opensearch

# View test container logs
docker compose logs test

# Check service status
docker compose ps

# Check OpenSearch health
curl -X GET "http://localhost:9200/_cluster/health?pretty"
```

### Cleanup
```bash
# Stop services
docker compose down

# Remove volumes too
docker compose down -v

# Remove everything including images
docker compose down -v --rmi all

# Prune unused Docker resources
docker system prune -a
```

## 🔧 Configuration

### Environment Variables
```bash
# Create .env from template
cp .env.example .env

# Edit for your system
nano .env
```

### Key Variables
```bash
OPENSEARCH_INITIAL_ADMIN_PASSWORD=TestPassword123!
OPENSEARCH_URL=http://opensearch:9200
UID=1000  # Your user ID (get with: id -u)
GID=1000  # Your group ID (get with: id -g)
```

## 🏗️ Building

```bash
# Build all services
docker compose build

# Build with no cache
docker compose build --no-cache

# Build specific service
docker compose build test

# Pull latest base images first
docker compose build --pull
```

## 📊 Monitoring

```bash
# Resource usage
docker stats

# Disk usage
docker system df

# Container info
docker compose ps
docker compose top

# Network info
docker network ls
docker network inspect opensearch-sugar_test-network
```

## 🐛 Troubleshooting

### OpenSearch won't start
```bash
# Check logs
docker compose logs opensearch

# Verify health
docker compose ps opensearch

# Restart
docker compose restart opensearch
```

### Permission errors
```bash
# Set correct UID/GID in .env
echo "UID=$(id -u)" >> .env
echo "GID=$(id -g)" >> .env

# Rebuild
docker compose build --no-cache test
```

### Slow builds
```bash
# Enable BuildKit
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# Clean cache
docker builder prune
```

### Tests can't connect
```bash
# Verify network
docker compose exec test ping opensearch

# Check environment
docker compose exec test env | grep OPENSEARCH

# Restart services
docker compose restart
```

## 📦 CI/CD

### GitHub Actions
```yaml
- run: |
    cp .env.example .env
    ./run-tests.sh --cleanup
```

### GitLab CI
```yaml
script:
  - cp .env.example .env
  - ./run-tests.sh --cleanup
```

## 💡 Tips

- Use `--rm` to auto-remove containers after running
- Use `-d` to run in detached mode
- Use `-f` to follow logs in real-time
- Use `--build` to rebuild before running
- Cache gems by keeping the `gems` volume
- Use `.dockerignore` to speed up builds

## 📞 Help

```bash
# Docker Compose help
docker compose --help
docker compose run --help

# View configuration
docker compose config

# Validate compose file
docker compose config --quiet
```

## 🎯 Best Practices

1. Always use `--rm` for one-off commands
2. Keep volumes for caching (gems, opensearch-data)
3. Use health checks for reliability
4. Clean up regularly with `docker compose down -v`
5. Pin versions in Dockerfiles
6. Use multi-stage builds
7. Leverage layer caching
8. Use .dockerignore

---

See `DOCKER.md` for detailed documentation.

