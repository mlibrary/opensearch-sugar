#!/usr/bin/env bash
# Quick development shell script
# Starts a shell in the test container with OpenSearch running

set -e

echo "🐚 Starting development shell..."

# Start OpenSearch in the background
docker compose up -d opensearch

# Wait for OpenSearch
echo "⏳ Waiting for OpenSearch..."
until docker compose ps opensearch | grep -q "healthy"; do
  echo -n "."
  sleep 2
done
echo ""
echo "✅ OpenSearch is ready!"

# Start interactive shell
echo "🚀 Starting Ruby shell (use 'exit' to quit)..."
docker compose run --rm test /bin/bash

