#!/bin/bash
# Reset and rebuild Meme Search with fresh database
# Usage: ./reset-and-rebuild.sh [--keep-models]

set -e

COMPOSE_FILE="docker-compose-local-build.yml"
KEEP_MODELS=false
KEEP_ALL=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --keep-models)
      KEEP_MODELS=true
      shift
      ;;
    --keep-all)
      KEEP_ALL=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--keep-models] [--keep-all]"
      exit 1
      ;;
  esac
done

echo "🛑 Stopping containers..."
docker compose -f "$COMPOSE_FILE" down

if [ "$KEEP_ALL" = true ]; then
  echo "✅ Keeping all data (database + models)..."
elif [ "$KEEP_MODELS" = true ]; then
  echo "🗑️  Removing database volumes (keeping model cache)..."
  rm -rf ./meme_search/db_data/meme-search-db
  rm -rf ./meme_search/db_data/image_to_text_generator
  echo "✅ Models cache preserved in ./meme_search/models/"
else
  echo "🗑️  Removing all volumes (including models)..."
  docker compose -f "$COMPOSE_FILE" down -v
fi

echo "🏗️  Rebuilding Rails and Python services without cache..."
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
docker compose -f "$COMPOSE_FILE" build --no-cache --build-arg GIT_COMMIT="$GIT_COMMIT" meme_search image_to_text_generator

echo "🚀 Starting fresh containers..."
docker compose -f "$COMPOSE_FILE" up

echo "✅ Reset complete! Fresh database with seed data."
