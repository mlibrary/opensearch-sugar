#!/usr/bin/env bash
# Integration test runner script
# Usage: ./run-tests.sh [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
REBUILD=false
CLEANUP=false
FOLLOW_LOGS=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --rebuild)
      REBUILD=true
      shift
      ;;
    --cleanup)
      CLEANUP=true
      shift
      ;;
    --logs)
      FOLLOW_LOGS=true
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Usage: $0 [--rebuild] [--cleanup] [--logs]"
      exit 1
      ;;
  esac
done

echo -e "${GREEN}🚀 Starting Integration Test Suite${NC}"
echo "================================================"

# Cleanup if requested
if [ "$CLEANUP" = true ]; then
  echo -e "${YELLOW}🧹 Cleaning up old containers and volumes...${NC}"
  docker compose down -v
fi

# Rebuild if requested
if [ "$REBUILD" = true ]; then
  echo -e "${YELLOW}🔨 Rebuilding containers...${NC}"
  docker compose build --no-cache
fi

# Start OpenSearch and wait for it to be healthy
echo -e "${YELLOW}🔧 Starting OpenSearch...${NC}"
docker compose up -d opensearch

# Wait for OpenSearch to be healthy
echo -e "${YELLOW}⏳ Waiting for OpenSearch to be ready...${NC}"
max_attempts=60
attempt=0
while [ $attempt -lt $max_attempts ]; do
  if docker compose ps opensearch | grep -q "healthy"; then
    echo -e "${GREEN}✅ OpenSearch is ready!${NC}"
    break
  fi
  attempt=$((attempt + 1))
  if [ $attempt -eq $max_attempts ]; then
    echo -e "${RED}❌ OpenSearch failed to start within timeout${NC}"
    docker compose logs opensearch
    exit 1
  fi
  echo -n "."
  sleep 2
done
echo ""

# Run tests
echo -e "${YELLOW}🧪 Running tests...${NC}"
if [ "$FOLLOW_LOGS" = true ]; then
  docker compose run --rm test
else
  docker compose run --rm test 2>&1
fi

TEST_EXIT_CODE=$?

# Show results
echo ""
echo "================================================"
if [ $TEST_EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}✅ All tests passed!${NC}"
else
  echo -e "${RED}❌ Tests failed with exit code: $TEST_EXIT_CODE${NC}"
fi

# Cleanup unless --no-cleanup is specified
if [ "$CLEANUP" != true ]; then
  echo -e "${YELLOW}💡 Tip: Run with --cleanup to remove containers after tests${NC}"
fi

exit $TEST_EXIT_CODE

